import unittest
from unittest.mock import patch, MagicMock, call, Mock
import os
import sys


class TestEnableAgentFallback(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        """Setup before all tests - mock problematic imports"""
        # Mock Unix-specific and Utils modules before importing AzureRM
        sys.modules['pwd'] = Mock()
        sys.modules['grp'] = Mock()
        cls.mock_util = Mock()
        cls.mock_handler_status = Mock()
        cls.mock_rm_status = Mock()
        
        sys.modules['Utils.HandlerUtil'] = cls.mock_util
        sys.modules['Utils.WAAgentUtil'] = Mock()
        sys.modules['Utils.RMExtensionStatus'] = cls.mock_rm_status
        sys.modules['ConfigureDeploymentAgent'] = Mock()
        sys.modules['DownloadDeploymentAgent'] = Mock()
        
        # Import after mocking
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
        global AzureRM
        import AzureRM as AzureRMModule
        AzureRM = AzureRMModule
    
    def setUp(self):
        """Setup for each test"""
        # Clear environment variable before each test
        if "VSTS_AGENT_VMEXT_FALLBACK_USED" in os.environ:
            del os.environ["VSTS_AGENT_VMEXT_FALLBACK_USED"]
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.isfile")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_fallback_used_when_download_fails_after_retries(self, mock_url_retrieve, mock_isdir, 
                                                               mock_exists, mock_isfile, mock_chmod, 
                                                               mock_popen, mock_handler_utility):
        """Verify fallback script is used when download fails after 3 retries"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        # Agent folder exists and .agent file doesn't exist
        mock_isdir.return_value = True
        mock_exists.return_value = False
        
        # First url_retrieve succeeds (agent download), second fails 3 times (script download)
        mock_url_retrieve.side_effect = [
            None,  # Agent download succeeds
            Exception("Download failed 1"),
            Exception("Download failed 2"),
            Exception("Download failed 3")
        ]
        
        # Bundled script exists
        script_dir = os.path.dirname(os.path.abspath(AzureRM.__file__))
        bundled_script_path = os.path.join(script_dir, "enableagent.sh")
        
        def isfile_mock(path):
            return path == bundled_script_path
        
        mock_isfile.side_effect = isfile_mock
        
        # Mock subprocess execution
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"success", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process
        
        # Execute
        AzureRM.enable_pipelines_agent(config)
        
        # Verify
        self.assertEqual(os.environ.get("VSTS_AGENT_VMEXT_FALLBACK_USED"), "true")
        self.assertEqual(mock_url_retrieve.call_count, 4)  # 1 for agent + 3 retries for script
        mock_chmod.assert_called_once_with(bundled_script_path, 0o777)
        mock_handler_utility.set_handler_status.assert_called()
        # Get the status object passed to set_handler_status
        status_object = mock_handler_utility.set_handler_status.call_args[0][0]
        self.assertEqual(status_object.status_message, "EnableAgent fallback script used")
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.isfile")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_environment_variable_set_when_fallback_used(self, mock_url_retrieve, mock_isdir, 
                                                          mock_exists, mock_isfile, mock_chmod, 
                                                          mock_popen, mock_handler_utility):
        """Verify VSTS_AGENT_VMEXT_FALLBACK_USED is set to true"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        mock_isdir.return_value = True
        mock_exists.return_value = False
        mock_url_retrieve.side_effect = [
            None,  # Agent download succeeds
            Exception("Fail 1"),
            Exception("Fail 2"),
            Exception("Fail 3")
        ]
        
        script_dir = os.path.dirname(os.path.abspath(AzureRM.__file__))
        bundled_script_path = os.path.join(script_dir, "enableagent.sh")
        mock_isfile.side_effect = lambda path: path == bundled_script_path
        
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"success", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process
        
        # Execute
        AzureRM.enable_pipelines_agent(config)
        
        # Verify
        self.assertEqual(os.environ["VSTS_AGENT_VMEXT_FALLBACK_USED"], "true")
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.isfile")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_bundled_script_path_used(self, mock_url_retrieve, mock_isdir, 
                                       mock_exists, mock_isfile, mock_chmod, 
                                       mock_popen, mock_handler_utility):
        """Verify bundled script path (enableagent.sh in same directory) is used"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        mock_isdir.return_value = True
        mock_exists.return_value = False
        mock_url_retrieve.side_effect = [None, Exception("F1"), Exception("F2"), Exception("F3")]
        
        script_dir = os.path.dirname(os.path.abspath(AzureRM.__file__))
        bundled_script_path = os.path.join(script_dir, "enableagent.sh")
        mock_isfile.side_effect = lambda path: path == bundled_script_path
        
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"success", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process
        
        # Execute
        AzureRM.enable_pipelines_agent(config)
        
        # Verify chmod called with bundled script path
        mock_chmod.assert_called_once_with(bundled_script_path, 0o777)
        
        # Verify Popen called with bundled script path
        popen_args = mock_popen.call_args[0][0]
        self.assertEqual(popen_args[1], bundled_script_path)
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_retry_count_three_before_fallback(self, mock_url_retrieve, mock_isdir, 
                                                 mock_exists, mock_chmod, 
                                                 mock_popen, mock_handler_utility):
        """Verify exactly 3 download retries occur before using fallback"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        mock_isdir.return_value = True
        mock_exists.return_value = False
        mock_url_retrieve.side_effect = [
            None,  # Agent download succeeds
            Exception("Fail 1"),
            Exception("Fail 2"),
            Exception("Fail 3")
        ]
        
        with patch("AzureRM.os.path.isfile", return_value=True):
            mock_process = MagicMock()
            mock_process.communicate.return_value = (b"success", b"")
            mock_process.returncode = 0
            mock_popen.return_value = mock_process
            
            # Execute
            AzureRM.enable_pipelines_agent(config)
        
        # Verify exactly 4 calls: 1 for agent download + 3 retries for script
        self.assertEqual(mock_url_retrieve.call_count, 4)
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.isfile")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_no_fallback_when_download_succeeds(self, mock_url_retrieve, mock_isdir, 
                                                  mock_exists, mock_isfile, mock_chmod, 
                                                  mock_popen, mock_handler_utility):
        """Verify fallback is not used when download succeeds"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        mock_isdir.return_value = True
        mock_exists.return_value = False
        mock_url_retrieve.return_value = None  # Both downloads succeed
        
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"success", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process
        
        # Execute
        AzureRM.enable_pipelines_agent(config)
        
        # Verify
        self.assertNotIn("VSTS_AGENT_VMEXT_FALLBACK_USED", os.environ)
        mock_isfile.assert_not_called()  # Bundled script check should not occur
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_environment_variable_not_set_on_success(self, mock_url_retrieve, mock_isdir, 
                                                       mock_exists, mock_chmod, 
                                                       mock_popen, mock_handler_utility):
        """Verify VSTS_AGENT_VMEXT_FALLBACK_USED is not set when download succeeds"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        mock_isdir.return_value = True
        mock_exists.return_value = False
        mock_url_retrieve.return_value = None
        
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"success", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process
        
        # Execute
        AzureRM.enable_pipelines_agent(config)
        
        # Verify
        self.assertNotIn("VSTS_AGENT_VMEXT_FALLBACK_USED", os.environ)
    
    @patch("AzureRM.handler_utility")
    @patch("AzureRM.subprocess.Popen")
    @patch("AzureRM.os.chmod")
    @patch("AzureRM.os.path.exists")
    @patch("AzureRM.os.path.isdir")
    @patch("AzureRM.Util.url_retrieve")
    def test_retry_count_one_on_success(self, mock_url_retrieve, mock_isdir, 
                                         mock_exists, mock_chmod, 
                                         mock_popen, mock_handler_utility):
        """Verify only 1 download attempt when successful"""
        # Setup
        config = {
            "EnableScriptParameters": "params",
            "AgentFolder": "/test/agent",
            "AgentDownloadUrl": "http://test.com/agent.tar.gz",
            "EnableScriptDownloadUrl": "http://test.com/enableagent.sh"
        }
        
        mock_isdir.return_value = True
        mock_exists.return_value = False
        mock_url_retrieve.return_value = None
        
        mock_process = MagicMock()
        mock_process.communicate.return_value = (b"success", b"")
        mock_process.returncode = 0
        mock_popen.return_value = mock_process
        
        # Execute
        AzureRM.enable_pipelines_agent(config)
        
        # Verify exactly 2 calls: 1 for agent + 1 for script
        self.assertEqual(mock_url_retrieve.call_count, 2)


if __name__ == '__main__':
    unittest.main()
