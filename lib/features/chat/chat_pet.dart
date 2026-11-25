import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'chat_pet_sprite.dart';

abstract final class ChatPet {
  /// Ambient default for [ChatPetLayer] hosts. The pet animates forever, so
  /// widget tests that settle animations switch it off in their test config.
  static bool enabled = true;
  static const size = Size(54, 72);
}

enum ChatPetPerchKind { reply, user, thinking, obstacle }

/// What the pet sees of the transcript: bubbles it may stand beside and
/// anything it must not cover.
@immutable
class PetPerch {
  const PetPerch(this.id, this.kind, this.rect, [this.order = -1]);
  final Object id;
  final ChatPetPerchKind kind;
  final Rect rect;

  /// Transcript position; larger is newer. Obstacles have no order.
  final int order;
}

enum PetSpot { beside, onTop, edge }

/// Where the pet rests. Anchored spots follow their bubble; edge spots are a
/// fraction of the transcript height on the right screen edge.
typedef PetPlacement = ({Object? anchor, PetSpot spot, double edge});

PetPlacement petEdge(double edge) =>
    (anchor: null, spot: PetSpot.edge, edge: edge);

/// Registry filled while the transcript builds. Keys are attached to the
/// tightly sized bubble boxes, never to full-width rows.
class ChatPetPerches {
  final _keys = <Object, GlobalKey>{};
  var _infos = <Object, ({GlobalKey key, ChatPetPerchKind kind, int order})>{};
  var _pending =
      <Object, ({GlobalKey key, ChatPetPerchKind kind, int order})>{};

  void begin() => _pending = {};

  GlobalKey key(Object id, ChatPetPerchKind kind, {int order = -1}) {
    final key = _keys.putIfAbsent(id, GlobalKey.new);
    _pending[id] = (key: key, kind: kind, order: order);
    return key;
  }

  void commit() {
    _infos = _pending;
    _keys.removeWhere((id, _) => !_infos.containsKey(id));
  }

  List<PetPerch> measure(RenderBox stage) => [
    for (final MapEntry(key: id, value: info) in _infos.entries)
      if (info.key.currentContext?.findRenderObject() case final RenderBox box
          when box.attached && box.hasSize)
        PetPerch(id, info.kind, _rectIn(box, stage), info.order),
  ];
}

Rect _rectIn(RenderBox box, RenderBox stage) => Rect.fromPoints(
  stage.globalToLocal(box.localToGlobal(Offset.zero)),
  stage.globalToLocal(box.localToGlobal(box.size.bottomRight(Offset.zero))),
);

Rect _bodyRect(Offset at, Size pet, Rect body) => Rect.fromLTRB(
  at.dx + body.left * pet.width,
  at.dy + body.top * pet.height,
  at.dx + body.right * pet.width,
  at.dy + body.bottom * pet.height,
);

/// Top-left of the pet for [placement], without checking that it fits.
@visibleForTesting
Offset? petOffset(
  PetPlacement placement, {
  required List<PetPerch> perches,
  required Rect viewport,
  required Size stage,
  Size pet = ChatPet.size,
}) {
  if (viewport.height < pet.height + 12) return null;
  if (placement.spot == PetSpot.edge) {
    return Offset(
      stage.width - pet.width * .5,
      viewport.top + 4 + placement.edge * (viewport.height - pet.height - 8),
    );
  }
  final anchor = perches.where((p) => p.id == placement.anchor).firstOrNull;
  if (anchor == null) return null;
  final r = anchor.rect;
  // Replies are left aligned, so the pet stands on their right; user bubbles
  // are right aligned, so it stands on their left.
  final right = anchor.kind != ChatPetPerchKind.user;
  return switch (placement.spot) {
    PetSpot.beside => Offset(
      right ? r.right - pet.width * .1 : r.left - pet.width * .9,
      r.bottom - pet.height,
    ),
    _ => Offset(
      right ? r.right - pet.width * .95 : r.left - pet.width * .05,
      r.top - pet.height + 4,
    ),
  };
}

/// Whether an anchored placement keeps the pet on screen, inside the
/// transcript, and off every other bubble's text.
@visibleForTesting
bool petFits(
  PetPlacement placement, {
  required List<PetPerch> perches,
  required Rect viewport,
  required Size stage,
  Size pet = ChatPet.size,
  Rect body = const Rect.fromLTRB(.12, .04, .89, .98),
}) {
  final at = petOffset(
    placement,
    perches: perches,
    viewport: viewport,
    stage: stage,
    pet: pet,
  );
  if (at == null) return false;
  if (placement.spot == PetSpot.edge) return true;
  final box = _bodyRect(at, pet, body);
  // The top of the transcript fades out; keep clear of it.
  if (box.left < 2 ||
      box.right > stage.width - 2 ||
      at.dy < viewport.top + 48 ||
      at.dy + pet.height > viewport.bottom + 2) {
    return false;
  }
  return perches.every(
    (p) => p.id == placement.anchor || !p.rect.overlaps(box),
  );
}

/// An edge slot whose visible half does not cover bubble text.
@visibleForTesting
double petFreeEdge(
  List<PetPerch> perches, {
  required Rect viewport,
  required Size stage,
  Size pet = ChatPet.size,
  double? avoid,
}) {
  for (final fraction in const [1.0, .82, .64, .46, .28, .1]) {
    if (avoid != null && (fraction - avoid).abs() < .2) continue;
    final at = petOffset(
      petEdge(fraction),
      perches: perches,
      viewport: viewport,
      stage: stage,
      pet: pet,
    );
    if (at == null) break;
    final box = _bodyRect(at, pet, const Rect.fromLTRB(.12, .04, .89, .98));
    // Bubble padding (12px) may be overlapped; text may not.
    if (perches.every(
      (p) => !Rect.fromLTRB(
        p.rect.left + 12,
        p.rect.top,
        p.rect.right - 12,
        p.rect.bottom,
      ).overlaps(box),
    )) {
      return fraction;
    }
  }
  return avoid == null ? 1 : (avoid > .5 ? .3 : .9);
}

enum _MoveKind { jump, scurry, hop }

class _Move {
  _Move(this.kind, this.from, this.to, this.start, this.duration, this.arc);
  final _MoveKind kind;
  final Offset from;
  final PetPlacement to;
  final Duration start, duration;
  final double arc;
  Offset? lastTo;

  double progress(Duration now) => duration == Duration.zero
      ? 1
      : ((now - start).inMicroseconds / duration.inMicroseconds).clamp(0, 1);
}

enum _Act { sway, bounce, look, wave, stretch }

/// The chat companion. Fills its parent; only the character itself takes
/// taps, and even those still reach the transcript so drags keep scrolling.
class ChatPetLayer extends StatefulWidget {
  const ChatPetLayer({
    super.key,
    required this.perches,
    required this.viewportKey,
    required this.scroll,
    this.animate = true,
    this.skin = ChatPetSkin.viitor,
  });

  final ChatPetPerches perches;

  /// The transcript box; the pet never rests outside it.
  final GlobalKey viewportKey;
  final ScrollController scroll;
  final bool animate;
  final ChatPetSkin skin;

  @override
  State<ChatPetLayer> createState() => _ChatPetLayerState();
}

class _ChatPetLayerState extends State<ChatPetLayer>
    with SingleTickerProviderStateMixin {
  static const _stableAfter = Duration(milliseconds: 450);
  static const _sleepAfter = Duration(seconds: 45);

  late final Ticker _ticker = createTicker(_tick);
  final _clock = _Clock();
  final _random = math.Random();
  var _reduceMotion = false;

  Duration _now = Duration.zero, _appearAt = Duration.zero;
  PetPlacement? _placement;
  _Move? _move;
  Offset? _lastOffset;
  bool _mirror = false;

  final _sizes = <Object, (Size, Duration)>{};
  bool _seenTranscript = false;
  Object? _latestId;
  ChatPetPerchKind? _latestKind;

  double _lastScroll = 0;
  Duration _returnAt = Duration.zero, _holdEdgeUntil = Duration.zero;
  Duration _activity = Duration.zero;
  bool _sleeping = false;

  Duration _nextBlink = const Duration(seconds: 2);
  Duration _nextAct = const Duration(seconds: 5);
  (_Act, Duration, Duration)? _act;
  ChatPetExpression _expression = ChatPetExpression.open;
  Duration _expressionUntil = Duration.zero;
  ChatPetEmote? _transientEmote, _shownEmote;
  Duration _emoteUntil = Duration.zero, _emoteStart = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !widget.animate || MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant ChatPetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reduceMotion = !widget.animate || MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  RenderBox? get _stage {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  Rect? _viewport(RenderBox stage) {
    final box = widget.viewportKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? _rectIn(box, stage)
        : null;
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    final stage = _stage;
    final view = stage == null ? null : _viewport(stage);
    if (stage != null && view != null) {
      final perches = widget.perches.measure(stage);
      _track(perches);
      _watchScroll();
      if (_move case final move? when move.progress(_now) >= 1) {
        _land(move, perches);
      }
      if (_move == null) _decide(perches, view, stage.size);
      _idle();
    }
    _clock.tick();
  }

  void _track(List<PetPerch> perches) {
    PetPerch? latest;
    for (final p in perches) {
      final previous = _sizes[p.id];
      if (previous == null) {
        // Bubbles present on open are settled history.
        _sizes[p.id] = (
          p.rect.size,
          _seenTranscript ? _now : _now - const Duration(seconds: 1),
        );
      } else if ((previous.$1.width - p.rect.width).abs() > .5 ||
          (previous.$1.height - p.rect.height).abs() > .5) {
        _sizes[p.id] = (p.rect.size, _now);
      }
      if (p.kind != ChatPetPerchKind.obstacle &&
          (latest == null || p.order > latest.order)) {
        latest = p;
      }
    }
    final present = {for (final p in perches) p.id};
    _sizes.removeWhere((id, _) => !present.contains(id));
    if (latest?.id != _latestId && _seenTranscript && latest != null) {
      _wake();
      if (latest.kind == ChatPetPerchKind.user) {
        _emote(ChatPetEmote.heart, const Duration(milliseconds: 1300));
      }
    }
    _latestId = latest?.id;
    _latestKind = latest?.kind;
    _seenTranscript = true;
  }

  bool _stable(PetPerch p) {
    final changed = _sizes[p.id]?.$2;
    return changed != null && _now - changed >= _stableAfter;
  }

  void _watchScroll() {
    final scroll = widget.scroll;
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    if ((offset - _lastScroll).abs() > .5) _wake(quiet: true);
    _lastScroll = offset;
    // The transcript is reversed: offset 0 shows the newest message.
    if (offset > 40) _returnAt = _now + const Duration(milliseconds: 650);
  }

  void _decide(List<PetPerch> perches, Rect view, Size stage) {
    bool fits(PetPlacement p) =>
        petFits(p, perches: perches, viewport: view, stage: stage);
    PetPlacement edge() => _placement?.spot == PetSpot.edge
        ? _placement!
        : petEdge(petFreeEdge(perches, viewport: view, stage: stage));

    final current = _placement;
    final holding = current != null && fits(current);
    PetPlacement desired;
    if (_now < _returnAt || _now < _holdEdgeUntil) {
      desired = edge();
    } else {
      PetPerch? reply;
      for (final p in perches) {
        if (p.kind == ChatPetPerchKind.reply &&
            (reply == null || p.order > reply.order)) {
          reply = p;
        }
      }
      final waiting =
          _latestKind == ChatPetPerchKind.thinking ||
          (reply != null && !_stable(reply));
      PetPlacement? next;
      if (reply != null && !waiting) {
        for (final spot in const [PetSpot.beside, PetSpot.onTop]) {
          final candidate = (anchor: reply.id, spot: spot, edge: 0.0);
          if (fits(candidate)) {
            next = candidate;
            break;
          }
        }
      }
      desired = next ?? (holding ? current : edge());
    }
    if (current == null) {
      _placement = desired;
      _appearAt = _now;
      _mirror = _restingMirror(desired, perches);
      return;
    }
    if (desired == current) return;
    _go(desired, perches, view, stage);
  }

  void _go(
    PetPlacement to,
    List<PetPerch> perches,
    Rect view,
    Size stage, {
    _MoveKind? kind,
  }) {
    final target = petOffset(
      to,
      perches: perches,
      viewport: view,
      stage: stage,
    );
    final from = _lastOffset ?? target;
    if (target == null || from == null || _reduceMotion) {
      _placement = to;
      _mirror = _restingMirror(to, perches);
      return;
    }
    final distance = (target - from).distance;
    kind ??= to.spot == PetSpot.edge
        ? _MoveKind.scurry
        : to.anchor == _placement?.anchor
        ? _MoveKind.hop
        : _MoveKind.jump;
    final duration = switch (kind) {
      _MoveKind.scurry => (380 + distance * 1.6).clamp(420, 1100),
      _MoveKind.jump => (640 + distance * .6).clamp(640, 980),
      _MoveKind.hop => 560,
    };
    final dx = target.dx - from.dx;
    if (dx.abs() > 4) _mirror = dx > 0;
    _act = null;
    _move = _Move(
      kind,
      from,
      to,
      _now,
      Duration(milliseconds: duration.round()),
      switch (kind) {
        _MoveKind.jump => 28 + math.min(60.0, distance * .18),
        _MoveKind.hop => 22,
        _MoveKind.scurry => 0,
      },
    );
  }

  void _land(_Move move, List<PetPerch> perches) {
    final arrived =
        move.to.anchor != null && move.to.anchor != _placement?.anchor;
    _placement = move.to;
    _move = null;
    _mirror = _restingMirror(move.to, perches);
    if (arrived && move.kind == _MoveKind.jump) {
      _emote(ChatPetEmote.sparkle, const Duration(milliseconds: 1100));
    }
  }

  /// The art waves with the hand on the viewer's left; keep it away from the
  /// bubble, and toward the screen when peeking from the edge.
  bool _restingMirror(PetPlacement p, List<PetPerch> perches) {
    if (p.spot == PetSpot.edge) return false;
    final anchor = perches.where((x) => x.id == p.anchor).firstOrNull;
    return anchor?.kind != ChatPetPerchKind.user;
  }

  void _idle() {
    if (_act case (_, final start, final length) when _now >= start + length) {
      _act = null;
    }
    if (!_sleeping &&
        _move == null &&
        _now - _activity > _sleepAfter &&
        _latestKind != ChatPetPerchKind.thinking) {
      _sleeping = true;
      _act = null;
    }
    if (_reduceMotion) return;
    if (_now >= _nextBlink) {
      if (_now >= _expressionUntil) {
        _face(ChatPetExpression.blink, const Duration(milliseconds: 130));
      }
      _nextBlink =
          _now +
          Duration(
            milliseconds: _random.nextDouble() < .2
                ? 280
                : 2200 + _random.nextInt(3300),
          );
    }
    if (_sleeping || _move != null || _act != null || _now < _nextAct) return;
    _nextAct = _now + Duration(milliseconds: 5000 + _random.nextInt(5000));
    final act = _Act.values[_random.nextInt(_Act.values.length)];
    final length = switch (act) {
      _Act.sway => 1600,
      _Act.bounce => 900,
      _Act.look => 1800,
      _Act.wave => 1400,
      _Act.stretch => 1200,
    };
    _act = (act, _now, Duration(milliseconds: length));
    switch (act) {
      case _Act.wave:
        _face(ChatPetExpression.happy, Duration(milliseconds: length));
        _emote(ChatPetEmote.note, Duration(milliseconds: length));
      case _Act.look when _random.nextBool():
        _emote(ChatPetEmote.question, const Duration(milliseconds: 1200));
      case _Act.bounce:
        _face(ChatPetExpression.happy, Duration(milliseconds: length));
      default:
    }
  }

  void _face(ChatPetExpression expression, Duration length) {
    _expression = expression;
    _expressionUntil = _now + length;
  }

  void _emote(ChatPetEmote emote, Duration length) {
    _transientEmote = emote;
    _emoteUntil = _now + length;
  }

  void _wake({bool quiet = false}) {
    _activity = _now;
    if (!_sleeping) return;
    _sleeping = false;
    if (!quiet) _emote(ChatPetEmote.exclaim, const Duration(milliseconds: 900));
  }

  void _tap() {
    final stage = _stage;
    final view = stage == null ? null : _viewport(stage);
    final placement = _placement;
    if (stage == null || view == null || placement == null || _move != null) {
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final perches = widget.perches.measure(stage);
    if (_sleeping) {
      _wake();
      _go(placement, perches, view, stage.size, kind: _MoveKind.hop);
      return;
    }
    _wake();
    final edgeNow = placement.spot == PetSpot.edge;
    if (!edgeNow && _random.nextDouble() < .55) {
      _face(ChatPetExpression.happy, const Duration(milliseconds: 900));
      _emote(ChatPetEmote.heart, const Duration(milliseconds: 1200));
      _go(placement, perches, view, stage.size, kind: _MoveKind.hop);
      return;
    }
    // Crawl along the screen edge for a moment, then come back.
    _holdEdgeUntil = _now + const Duration(milliseconds: 2800);
    _emote(
      edgeNow ? ChatPetEmote.note : ChatPetEmote.exclaim,
      const Duration(milliseconds: 1000),
    );
    _go(
      petEdge(
        petFreeEdge(
          perches,
          viewport: view,
          stage: stage.size,
          avoid: edgeNow ? placement.edge : null,
        ),
      ),
      perches,
      view,
      stage.size,
      kind: _MoveKind.scurry,
    );
  }

  /// Called while painting, after layout, so the pet tracks its bubble in
  /// the same frame the bubble moves.
  Offset? _locate(RenderBox stage) {
    final view = _viewport(stage);
    final placement = _placement;
    if (view == null || placement == null) return null;
    final perches = widget.perches.measure(stage);
    Offset? at(PetPlacement p) =>
        petOffset(p, perches: perches, viewport: view, stage: stage.size);
    final Offset? result;
    if (_move case final move?) {
      final to = at(move.to) ?? move.lastTo ?? move.from;
      move.lastTo = to;
      result = _travel(move, to, move.progress(_now));
    } else {
      result = at(placement) ?? _lastOffset;
    }
    _lastOffset = result;
    return result;
  }

  Offset _travel(_Move move, Offset to, double t) {
    if (move.kind == _MoveKind.scurry) {
      return Offset.lerp(move.from, to, Curves.easeInOutCubic.transform(t))!;
    }
    if (t < .18) return move.from;
    if (t > .84) return to;
    final u = (t - .18) / .66;
    final p = Offset.lerp(move.from, to, Curves.easeInOutSine.transform(u))!;
    return p - Offset(0, move.arc * 4 * u * (1 - u));
  }

  ChatPetFrame _frame() {
    final opacity = ((_now - _appearAt).inMilliseconds / 350).clamp(0.0, 1.0);
    var mirror = _mirror;
    if (_reduceMotion) {
      return ChatPetFrame(mirror: mirror, opacity: _placement == null ? 0 : 1);
    }
    final s = _now.inMicroseconds / 1e6;
    var sx = 1.0, sy = 1.0, tilt = 0.0, lift = 0.0;
    if (_move case final move?) {
      final t = move.progress(_now);
      final direction = move.kind == _MoveKind.hop ? 0 : (mirror ? 1 : -1);
      if (move.kind == _MoveKind.scurry) {
        final w = math.sin(s * math.pi * 2 * 4.5);
        tilt = w * .12;
        lift = w.abs() * 3;
      } else if (t < .18) {
        final e = Curves.easeOut.transform(t / .18);
        sy = 1 - .16 * e;
        sx = 1 + .1 * e;
      } else if (t <= .84) {
        final u = (t - .18) / .66;
        final stretch = .09 * (1 - u);
        sy = 1 + stretch;
        sx = 1 - stretch * .6;
        tilt = direction * .16 * (1 - 2 * u);
      } else {
        final q = math.sin((t - .84) / .16 * math.pi) * .15;
        sy = 1 - q;
        sx = 1 + q * .7;
      }
    } else {
      final period = _sleeping ? 3.8 : 2.6;
      final breath = (1 - math.cos(s * 2 * math.pi / period)) / 2;
      sy = 1 + (_sleeping ? .015 : .028) * breath;
      sx = 1 - .01 * breath;
      tilt = math.sin(s * math.pi / period) * .025;
      if (_placement?.spot == PetSpot.edge) tilt -= .2;
      if (_sleeping) {
        sy *= .95;
        tilt += .06;
      }
      if (_act case (final act, final start, final length)) {
        final tau = ((_now - start).inMicroseconds / length.inMicroseconds)
            .clamp(0.0, 1.0);
        final envelope = math.sin(tau * math.pi);
        switch (act) {
          case _Act.sway:
            tilt += math.sin(tau * math.pi * 4) * .1 * envelope;
          case _Act.bounce:
            final h = math.sin(tau * math.pi * 4).abs();
            lift += h * 6;
            sy *= 1 + (h - .5) * .05;
          case _Act.look:
            if (tau > .2 && tau < .8) mirror = !mirror;
          case _Act.wave:
            tilt += math.sin(tau * math.pi * 6) * .07 * envelope;
          case _Act.stretch:
            sy *= 1 + .07 * envelope;
            sx *= 1 - .04 * envelope;
        }
      }
    }
    return ChatPetFrame(
      scaleX: sx,
      scaleY: sy,
      tilt: tilt,
      lift: lift,
      mirror: mirror,
      opacity: opacity,
    );
  }

  ChatPetEmote? get _currentEmote {
    if (_now < _emoteUntil) return _transientEmote;
    if (_sleeping) return ChatPetEmote.sleep;
    if (_latestKind == ChatPetPerchKind.thinking) return ChatPetEmote.thinking;
    return null;
  }

  @override
  Widget build(BuildContext context) => _PetStage(
    locate: _locate,
    repaint: _clock,
    child: ExcludeSemantics(
      child: GestureDetector(
        onTap: _tap,
        child: ListenableBuilder(
          listenable: _clock,
          builder: (context, _) {
            final emote = _currentEmote;
            if (emote != _shownEmote) {
              _shownEmote = emote;
              _emoteStart = _now;
            }
            return ChatPetSprite(
              key: const ValueKey('chat-pet'),
              size: ChatPet.size,
              skin: widget.skin,
              frame: _frame(),
              expression: _sleeping
                  ? ChatPetExpression.sleepy
                  : _now < _expressionUntil
                  ? _expression
                  : ChatPetExpression.open,
              emote: emote,
              emoteProgress: _reduceMotion
                  ? 1
                  : (_now - _emoteStart).inMilliseconds / 450,
              emoteOnLeft: _placement?.spot == PetSpot.edge,
              shadow: _placement?.spot != PetSpot.edge || _move != null,
            );
          },
        ),
      ),
    ),
  );
}

class _Clock extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _PetStage extends SingleChildRenderObjectWidget {
  const _PetStage({required this.locate, required this.repaint, super.child});
  final Offset? Function(RenderBox stage) locate;
  final Listenable repaint;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPetStage(locate, repaint);

  @override
  void updateRenderObject(BuildContext context, _RenderPetStage renderObject) {
    renderObject
      ..locate = locate
      ..repaint = repaint;
  }
}

class _RenderPetStage extends RenderProxyBox {
  _RenderPetStage(this.locate, this._repaint);
  Offset? Function(RenderBox stage) locate;
  Listenable _repaint;
  Offset? _childOffset;

  set repaint(Listenable value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    child?.layout(BoxConstraints.loose(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    _childOffset = child == null ? null : locate(this);
    if (child != null && _childOffset != null) {
      context.paintChild(child, offset + _childOffset!);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = _childOffset ?? Offset.zero;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  /// Adds the pet to the hit path but reports a miss, so the transcript
  /// below also receives the pointer and can still win a scroll drag.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    final at = _childOffset;
    if (child == null || at == null) return false;
    if (!(at & child.size).contains(position)) return false;
    result.addWithPaintOffset(
      offset: at,
      position: position,
      hitTest: (result, local) => child.hitTest(result, position: local),
    );
    return false;
  }
}
