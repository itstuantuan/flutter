import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("google_config", Path(__file__).resolve().parents[2] / "scripts/configure_google_sign_in.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GoogleConfigTests(unittest.TestCase):
    def test_reversed_scheme_and_no_secret(self):
        text = module.render({"GOOGLE_IOS_CLIENT_ID": "123-ios.apps.googleusercontent.com",
                              "GOOGLE_SERVER_CLIENT_ID": "123-web.apps.googleusercontent.com",
                              "API_SECRET_KEY": "must-not-copy"})
        self.assertIn("com.googleusercontent.apps.123-ios", text)
        self.assertNotIn("must-not-copy", text)
        self.assertNotIn("123-web", text)

    def test_missing_config_keeps_phone_login_buildable(self):
        self.assertIn("google-unconfigured", module.render({}))

    def test_invalid_client_id_cannot_inject_xcode_settings(self):
        with self.assertRaises(ValueError):
            module.render({"GOOGLE_IOS_CLIENT_ID": "bad\nCODE_SIGNING_ALLOWED=NO"})


if __name__ == "__main__":
    unittest.main()
