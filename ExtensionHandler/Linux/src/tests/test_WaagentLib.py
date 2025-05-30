import unittest
from unittest.mock import patch, MagicMock
import sys

import WaagentLib


class TestDistInfo(unittest.TestCase):
    @patch("WaagentLib.platform")
    def test_freebsd(self, mock_platform):
        mock_platform.system = lambda: "FreeBSD"
        mock_platform.release = lambda: "13.2-RELEASE-p2"
        result = WaagentLib.DistInfo()
        self.assertEqual(result[0], "FreeBSD")
        self.assertEqual(result[1], "13.2")

    @patch("WaagentLib.platform")
    def test_nsbdsd(self, mock_platform):
        mock_platform.system = lambda: "NS-BSD"
        mock_platform.release = lambda: "1.0-RELEASE"
        result = WaagentLib.DistInfo()
        self.assertEqual(result[0], "NS-BSD")
        self.assertEqual(result[1], "1.0")

    @patch("WaagentLib.platform")
    def test_linux_version_detection(self, mock_platform):
        mock_platform.system = lambda: "Linux"
        mock_platform.version = lambda: "centos 7.9"
        result = WaagentLib.DistInfo()
        self.assertEqual(result[0], "centos")

    @patch("WaagentLib.platform")
    def test_linux_version_detection(self, mock_platform):
        mock_platform.system = lambda: "Linux"
        mock_platform.version = lambda: "#15-Ubuntu SMP PREEMPT_DYNAMIC Sun Apr  6 15:05:05 UTC 2025"
        result = WaagentLib.DistInfo()
        self.assertEqual(result[0], "Ubuntu")

    @patch("WaagentLib.platform")
    def test_linux_default(self, mock_platform):
        mock_platform.system = lambda: "Linux"
        mock_platform.version = lambda: "unknown"
        result = WaagentLib.DistInfo()
        self.assertEqual(result[0], "Default")

    @patch("WaagentLib.platform")
    def test_other(self, mock_platform):
        mock_platform.system = lambda: "OtherOS"
        mock_platform.dist = lambda: ["Other", "1.0"]
        result = WaagentLib.DistInfo()
        self.assertEqual(result[0], "Other")
        self.assertEqual(result[1], "1.0")


class TestMainMethod(unittest.TestCase):
    @patch("WaagentLib.sys")
    @patch("WaagentLib.LoggerInit")
    @patch("WaagentLib.DistInfo")
    @patch("WaagentLib.GetMyDistro")
    @patch("WaagentLib.ConfigurationProvider")
    def test_main_prints_warning_for_empty_version(self, mock_config, mock_getmydistro, mock_distinfo, mock_loggerinit, mock_sys):
        # Setup
        mock_sys.argv = ["waagent", "-help"]
        WaagentLib.GuestAgentVersion = ""
        mock_distinfo.return_value = ["Ubuntu", "20.04"]
        mock_getmydistro.return_value = MagicMock()
        mock_config.return_value = MagicMock(get=lambda key: None)
        mock_sys.exit = MagicMock(side_effect=SystemExit)
        # Test
        with self.assertRaises(SystemExit):
            WaagentLib.main()
        # Check
        mock_loggerinit.assert_called()
        mock_distinfo.assert_called()
        mock_getmydistro.assert_called()

    @patch("WaagentLib.sys")
    def test_main_usage_on_no_args(self, mock_sys):
        mock_sys.argv = ["waagent"]
        mock_sys.exit = MagicMock(side_effect=SystemExit)
        with self.assertRaises(SystemExit):
            WaagentLib.main()
        mock_sys.exit.assert_called()

    @patch("WaagentLib.sys")
    @patch("WaagentLib.LoggerInit")
    @patch("WaagentLib.DistInfo")
    @patch("WaagentLib.GetMyDistro")
    @patch("WaagentLib.ConfigurationProvider")
    def test_main_version_argument(self, mock_config, mock_getmydistro, mock_distinfo, mock_loggerinit, mock_sys):
        mock_sys.argv = ["waagent", "-version"]
        WaagentLib.GuestAgentVersion = "WALinuxAgent-2.0.16"
        mock_distinfo.return_value = ["Ubuntu", "20.04"]
        mock_getmydistro.return_value = MagicMock()
        mock_config.return_value = MagicMock(get=lambda key: None)
        mock_sys.exit = MagicMock(side_effect=SystemExit)
        with self.assertRaises(SystemExit):
            WaagentLib.main()
        mock_sys.exit.assert_called()

    @patch("WaagentLib.sys")
    @patch("WaagentLib.LoggerInit")
    @patch("WaagentLib.DistInfo")
    @patch("WaagentLib.GetMyDistro")
    @patch("WaagentLib.ConfigurationProvider")
    def test_main_install_argument(self, mock_config, mock_getmydistro, mock_distinfo, mock_loggerinit, mock_sys):
        mock_sys.argv = ["waagent", "-install"]
        WaagentLib.GuestAgentVersion = "WALinuxAgent-2.0.16"
        mock_distinfo.return_value = ["Ubuntu", "20.04"]
        mock_distro = MagicMock()
        mock_distro.Install.return_value = 0
        mock_getmydistro.return_value = mock_distro
        mock_config.return_value = MagicMock(get=lambda key: None)
        mock_sys.exit = MagicMock(side_effect=SystemExit)
        with self.assertRaises(SystemExit):
            WaagentLib.main()
        mock_distro.Install.assert_called()
        mock_sys.exit.assert_called()

    @patch("WaagentLib.sys")
    @patch("WaagentLib.LoggerInit")
    @patch("WaagentLib.DistInfo")
    @patch("WaagentLib.GetMyDistro")
    @patch("WaagentLib.ConfigurationProvider")
    def test_main_uninstall_argument(self, mock_config, mock_getmydistro, mock_distinfo, mock_loggerinit, mock_sys):
        mock_sys.argv = ["waagent", "-uninstall"]
        WaagentLib.GuestAgentVersion = "WALinuxAgent-2.0.16"
        mock_distinfo.return_value = ["Ubuntu", "20.04"]
        mock_getmydistro.return_value = MagicMock()
        mock_config.return_value = MagicMock(get=lambda key: None)
        mock_sys.exit = MagicMock(side_effect=SystemExit)
        with patch("WaagentLib.Uninstall", return_value=0) as mock_uninstall:
            with self.assertRaises(SystemExit):
                WaagentLib.main()
            mock_uninstall.assert_called()
            mock_sys.exit.assert_called()

    @patch("WaagentLib.sys")
    @patch("WaagentLib.LoggerInit")
    @patch("WaagentLib.DistInfo")
    @patch("WaagentLib.GetMyDistro")
    @patch("WaagentLib.ConfigurationProvider")
    def test_main_deprovision_argument(self, mock_config, mock_getmydistro, mock_distinfo, mock_loggerinit, mock_sys):
        mock_sys.argv = ["waagent", "-deprovision+user", "-force"]
        WaagentLib.GuestAgentVersion = "WALinuxAgent-2.0.16"
        mock_distinfo.return_value = ["Ubuntu", "20.04"]
        mock_getmydistro.return_value = MagicMock()
        mock_config.return_value = MagicMock(get=lambda key: None)
        mock_sys.exit = MagicMock(side_effect=SystemExit)
        with patch("WaagentLib.Deprovision", return_value=0) as mock_deprovision:
            with self.assertRaises(SystemExit):
                WaagentLib.main()
            mock_deprovision.assert_called_with(True, True)


if __name__ == "__main__":
    unittest.main()
