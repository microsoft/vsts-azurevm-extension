# pylint: disable=missing-module-docstring
# pylint: disable=missing-function-docstring
# pylint: disable=missing-class-docstring
# pylint: disable=invalid-name

import unittest
from textwrap import dedent
from unittest.mock import patch, MagicMock
import json
import urllib.request
from mock import mock_open
from Utils import HandlerUtil


def urlopen_mock_read():
    mock = MagicMock()
    with open("net6.json", "r", encoding='utf-8') as net6_file:
        mock.read.return_value = net6_file.read()
    return mock

def urlopen_mock_with_exception():
    mock = MagicMock()
    mock.read.side_effect = Exception('urlopen error')
    return mock

@patch('urllib.request.urlopen', return_value=urlopen_mock_read())
class TestNet6Deprecation(unittest.TestCase):
    def test_ubuntu_1604(self, _urllib_mock):
        os_release = dedent('''
                             NAME="Ubuntu"
                             VERSION="16.04.7 LTS (Xenial Xerus)"
                             ID=ubuntu
                             ID_LIKE=debian
                             PRETTY_NAME="Ubuntu 16.04.7 LTS"
                             VERSION_ID="16.04"
                             HOME_URL="http://www.ubuntu.com/"
                             SUPPORT_URL="http://help.ubuntu.com/"
                             BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
                             VERSION_CODENAME=xenial
                             UBUNTU_CODENAME=xenial''')
        with patch('builtins.open', mock_open(read_data=os_release)):
            handler_util = HandlerUtil.HandlerUtility("-","-","-","-","-")
            self.assertTrue(handler_util.does_system_persists_in_net6_whitelist())

    def test_ubuntu_2004(self, _urllib_mock):
        os_release = dedent('''
                             NAME="Ubuntu"
                             VERSION="20.04.3 LTS (Focal Fossa)"
                             ID=ubuntu
                             ID_LIKE=debian
                             PRETTY_NAME="Ubuntu 20.04.3 LTS"
                             VERSION_ID="20.04"
                             HOME_URL="https://www.ubuntu.com/"
                             SUPPORT_URL="https://help.ubuntu.com/"
                             BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
                             PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
                             VERSION_CODENAME=focal
                             UBUNTU_CODENAME=focal''')
        with patch('builtins.open', mock_open(read_data=os_release)):
            handler_util = HandlerUtil.HandlerUtility("-","-","-","-","-")
            self.assertTrue(handler_util.does_system_persists_in_net6_whitelist())

    def test_ubuntu_2204(self, _urllib_mock):
        os_release = dedent('''
                            PRETTY_NAME="Ubuntu 22.10"
                            NAME="Ubuntu"
                            VERSION_ID="22.10"
                            VERSION="22.10 (Kinetic Kudu)"
                            VERSION_CODENAME=kinetic
                            ID=ubuntu
                            ID_LIKE=debian
                            HOME_URL="https://www.ubuntu.com/"
                            SUPPORT_URL="https://help.ubuntu.com/"
                            BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
                            PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
                            UBUNTU_CODENAME=kinetic
                            LOGO=ubuntu-logo''')
        with patch('builtins.open', mock_open(read_data=os_release)):
            handler_util = HandlerUtil.HandlerUtility("-","-","-","-","-")
            self.assertTrue(handler_util.does_system_persists_in_net6_whitelist())

    def test_rhel_84(self, _urllib_mock):
        os_release = dedent('''
                            NAME="Red Hat Enterprise Linux"
                            VERSION="8.4 (Ootpa)"
                            ID="rhel"
                            ID_LIKE="fedora"
                            VERSION_ID="8.4"
                            PLATFORM_ID="platform:el8"
                            PRETTY_NAME="Red Hat Enterprise Linux 8.4 (Ootpa)"
                            ANSI_COLOR="0;31"
                            CPE_NAME="cpe:/o:redhat:enterprise_linux:8.4:GA"
                            HOME_URL="https://www.redhat.com/"
                            DOCUMENTATION_URL="https://access.redhat.com/documentation/red_hat_enterprise_linux/8/"
                            BUG_REPORT_URL="https://bugzilla.redhat.com/"

                            REDHAT_BUGZILLA_PRODUCT="Red Hat Enterprise Linux 8"
                            REDHAT_BUGZILLA_PRODUCT_VERSION=8.4
                            REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux"
                            REDHAT_SUPPORT_PRODUCT_VERSION="8.4"''')
        with patch('builtins.open', mock_open(read_data=os_release)):
            handler_util = HandlerUtil.HandlerUtility("-","-","-","-","-")
            self.assertTrue(handler_util.does_system_persists_in_net6_whitelist())

    def test_unknown(self, _urllib_mock):
        os_release = dedent('''
                            NAME="Unknown Linux"
                            VERSION="0.1"
                            ID="unknown"
                            ID_LIKE="debian"
                            VERSION_ID="0.1"''')
        with patch('builtins.open', mock_open(read_data=os_release)):
            handler_util = HandlerUtil.HandlerUtility("-","-","-","-","-")
            self.assertFalse(handler_util.does_system_persists_in_net6_whitelist())


@patch('urllib.request.urlopen', return_value=urlopen_mock_with_exception())
class TestNet6DeprecationLocalFileFallback(unittest.TestCase):
    def test_file_fallback(self, _urllib_mock):
        with patch('builtins.open', new_callable=mock_open, read_data='{}') as open_mock:
            handler_util = HandlerUtil.HandlerUtility("-","-","-","-","-")
            self.assertFalse(handler_util.does_system_persists_in_net6_whitelist())
            # first open is for /etc/os-release
            # second open should happen due to urllib.request.urlopen exception
            # while trying to open ../net6.json
            self.assertEqual(open_mock.call_count, 2)


if __name__ == '__main__':
    unittest.main()
