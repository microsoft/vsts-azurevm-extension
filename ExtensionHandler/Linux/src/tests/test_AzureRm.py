# pylint: disable=missing-module-docstring
# pylint: disable=missing-function-docstring
# pylint: disable=missing-class-docstring
# pylint: disable=invalid-name

import unittest
from unittest.mock import patch, MagicMock
import AzureRM

class TestNet6Compatibility(unittest.TestCase):
    def test_is_os_compatible_returns_None(self):
        mm = MagicMock()
        mm.does_system_persists_in_net6_whitelist.return_value = True
        with patch('AzureRM.handler_utility', mm):
            self.assertIsNone(AzureRM.os_compatible_with_dotnet6())

    def test_is_os_compatible_raises_exception(self):
        mm = MagicMock()
        mm.does_system_persists_in_net6_whitelist.return_value = False
        with patch('AzureRM.handler_utility', mm):
            with self.assertRaises(Exception) as context:
                AzureRM.os_compatible_with_dotnet6()
            self.assertTrue('https://aka.ms/azdo-pipeline-agent-version' in str(context.exception))


if __name__ == '__main__':
    unittest.main()
