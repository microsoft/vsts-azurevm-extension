"""Exercise both Linux handlers under Python 3 with mocked extension dependencies."""

import hashlib
import importlib.util
import io
import os
import sys
import tempfile
import types
import unittest
from unittest.mock import MagicMock, patch


class CompatDict(dict):
    def has_key(self, key):
        return key in self


class CompatError(ValueError):
    # Python 2 exceptions expose .message; keep the handler's original error path.
    @property
    def message(self):
        return str(self)


def load_handler(name):
    source = os.path.join(os.path.dirname(__file__), "..", name + ".py")
    dependencies = {}
    for package in ("Utils", "Utils_python2"):
        dependencies[package] = types.ModuleType(package)
        for child in ("HandlerUtil", "RMExtensionStatus", "Constants", "WAAgentUtil", "GlobalSettings"):
            module = MagicMock()
            dependencies[package + "." + child] = module
            setattr(dependencies[package], child, module)
    for dependency in ("DownloadDeploymentAgent", "ConfigureDeploymentAgent", "DownloadDeploymentAgent_python2", "ConfigureDeploymentAgent_python2"):
        dependencies[dependency] = MagicMock()
    dependencies["urllib2"] = MagicMock()
    dependencies["distutils.version"] = MagicMock()
    with patch.dict(sys.modules, dependencies):
        spec = importlib.util.spec_from_file_location(name, source)
        module = importlib.util.module_from_spec(spec)
        if name == "AzureRM_python2":
            module.basestring = str
        spec.loader.exec_module(module)
    module.ValueError = CompatError
    module.proxy_config = {}
    return module


class IntegrityTests:
    handler_name = None

    def setUp(self):
        self.module = load_handler(self.handler_name)
        self.module.handler_utility = MagicMock()
        self.module.set_error_status_and_error_exit = MagicMock(side_effect=SystemExit)
        self.config = {
            "IntegrityMode": "enforce",
            "AgentFolder": os.path.abspath(os.path.join(os.path.dirname(__file__), "mock-agent")),
            "AgentDownloadUrl": "https://mirror.invalid/vsts-agent-linux-x64-1.2.3.tar.gz",
            "AgentDownloadSha256": hashlib.sha256(b"agent").hexdigest().upper(),
            "EnableScriptDownloadUrl": "https://another-mirror.invalid/bootstrap.sh",
            "EnableScriptSha256": hashlib.sha256(b"script").hexdigest(),
            "EnableScriptParameters": "-token protected-test-token",
        }
        self.files = {}
        self.agent = os.path.join(self.config["AgentFolder"], os.path.basename(self.config["AgentDownloadUrl"]))
        self.script = os.path.join(self.config["AgentFolder"], os.path.basename(self.config["EnableScriptDownloadUrl"]))
        self.bundle = os.path.join(os.path.dirname(os.path.abspath(self.module.__file__)), "enableagent.sh")
        self.downloaded_agent = b"agent"
        self.downloaded_script = b"script"

        def download(url, target):
            content = self.downloaded_agent if url == self.config["AgentDownloadUrl"] else self.downloaded_script
            if isinstance(content, Exception):
                raise content
            self.files[target] = content

        def read_file(path, mode):
            self.assertEqual(mode, "rb")
            if path not in self.files:
                raise CompatError("File not found")
            return io.BytesIO(self.files[path])

        for target, name, value in (
            (self.module, "open", read_file),
            (self.module.os.path, "isdir", MagicMock(return_value=True)),
            (self.module.os.path, "exists", MagicMock(return_value=False)),
            (self.module.os.path, "isfile", lambda path: path in self.files),
            (self.module.os, "chmod", MagicMock()),
            (self.module.shutil, "copyfile", MagicMock()),
            (self.module.subprocess, "Popen", MagicMock()),
        ):
            replacement = patch.object(target, name, value, create=True)
            replacement.start()
            self.addCleanup(replacement.stop)
        environment = patch.dict(os.environ, {}, clear=True)
        environment.start()
        self.addCleanup(environment.stop)
        self.module.Util.url_retrieve.side_effect = download
        self.module.subprocess.Popen.return_value.communicate.return_value = (b"success", b"")
        self.module.subprocess.Popen.return_value.returncode = 0

    def run_agent(self, expect_exit=False):
        if expect_exit:
            with self.assertRaises(SystemExit):
                self.module.enable_pipelines_agent(self.config)
        else:
            self.module.enable_pipelines_agent(self.config)

    def assert_blocked(self):
        self.module.subprocess.Popen.assert_not_called()
        self.module.set_error_status_and_error_exit.assert_called()

    def test_downloads_are_verified_once_and_preserve_url_filenames(self):
        with patch.object(self.module, "verify_file_sha256", wraps=self.module.verify_file_sha256) as verify:
            self.run_agent()
        self.assertEqual(verify.call_count, 2)
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.module.subprocess.Popen.assert_called_once()
        self.assertEqual(self.module.subprocess.Popen.call_args[0][0][1], self.script)
        self.assertEqual(self.files[self.agent], b"agent")
        self.assertEqual(self.files[self.script], b"script")

    def test_absent_and_explicit_legacy_do_not_verify_hashes(self):
        for mode in (None, "legacy"):
            with self.subTest(mode=mode):
                if mode is None:
                    self.config.pop("IntegrityMode")
                else:
                    self.config["IntegrityMode"] = mode
                self.config["AgentDownloadUrl"] = "http://legacy.invalid/agent.tar.gz"
                self.config["EnableScriptDownloadUrl"] = "http://legacy.invalid/enableagent.sh"
                self.config["AgentDownloadSha256"] = "invalid"
                self.config["EnableScriptSha256"] = None
                with patch.object(self.module, "verify_file_sha256") as verify:
                    self.run_agent()
                    verify.assert_not_called()
                self.module.set_error_status_and_error_exit.assert_not_called()
                self.assertIn(os.path.join(self.config["AgentFolder"], "agent.tar.gz"), self.files)
        self.assertEqual(self.module.subprocess.Popen.call_count, 2)

    def test_missing_and_malformed_hashes_fail_comparison_without_execution(self):
        for key in ("AgentDownloadSha256", "EnableScriptSha256"):
            original = self.config.pop(key)
            self.run_agent(expect_exit=True)
            self.assert_blocked()
            self.assertIn("Hash verification failed", str(self.module.set_error_status_and_error_exit.call_args[0][0]))
            for value in (None, "", original[:-1], "g" * 64, original + "\n", original + "\0", 1, [original]):
                with self.subTest(key=key, value=value):
                    self.config[key] = value
                    self.run_agent(expect_exit=True)
                    self.assert_blocked()
                    self.module.Util.url_retrieve.assert_called()
                    self.assertIn("Hash verification failed", str(self.module.set_error_status_and_error_exit.call_args[0][0]))
            self.config[key] = original

    def test_agent_mismatch_prevents_bootstrap_download(self):
        self.downloaded_agent = b"different agent"
        for mode in ("enforce", "agentenforce"):
            with self.subTest(mode=mode):
                self.config["IntegrityMode"] = mode
                self.module.Util.url_retrieve.reset_mock()
                self.run_agent(expect_exit=True)
                self.assert_blocked()
                self.assertNotIn(self.script, self.files)
                self.assertEqual(self.module.Util.url_retrieve.call_count, 1 if self.handler_name.endswith("python2") else 3)

    def test_agent_only_verifies_agent_without_verifying_script(self):
        self.config["IntegrityMode"] = "agentenforce"
        self.config.pop("EnableScriptSha256")
        self.downloaded_script = b"unverified script"
        for script_hash in (None, "not-a-hash"):
            with self.subTest(script_hash=script_hash):
                if script_hash is not None:
                    self.config["EnableScriptSha256"] = script_hash
                with patch.object(self.module, "verify_file_sha256", wraps=self.module.verify_file_sha256) as verify:
                    self.run_agent()
                    verify.assert_called_once_with(self.agent, self.config["AgentDownloadSha256"])
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.assertEqual(self.module.subprocess.Popen.call_count, 2)

    def test_agent_only_requires_matching_agent_hash(self):
        self.config["IntegrityMode"] = "agentenforce"
        original = self.config.pop("AgentDownloadSha256")
        self.run_agent(expect_exit=True)
        self.assert_blocked()
        for value in (None, "", original[:-1], "g" * 64, original + "\n", 1, [original]):
            with self.subTest(value=value):
                self.config["AgentDownloadSha256"] = value
                self.module.Util.url_retrieve.reset_mock()
                self.run_agent(expect_exit=True)
                self.assert_blocked()
                self.assertNotIn(self.script, self.files)
                self.assertEqual(self.module.Util.url_retrieve.call_count, 1 if self.handler_name.endswith("python2") else 3)

    def test_script_mismatch_without_bundle_prevents_execution(self):
        self.downloaded_script = b"different script"
        self.run_agent(expect_exit=True)
        self.assert_blocked()

    def test_download_failure_never_executes_cached_script(self):
        self.files[self.script] = b"cached script"
        self.downloaded_script = CompatError("Network unavailable")
        self.run_agent(expect_exit=True)
        self.assert_blocked()

    def test_leaves_cached_archives_to_bootstrap(self):
        cached_archive = os.path.join(self.config["AgentFolder"], "vsts-agent-old.tar.gz")
        self.files[cached_archive] = b"old archive"
        self.run_agent()
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.module.subprocess.Popen.assert_called_once()
        self.assertEqual(self.files[cached_archive], b"old archive")

    def test_enforce_preserves_existing_extracted_agent(self):
        self.files[os.path.join(self.config["AgentFolder"], "bin", "Agent.Listener")] = b"old agent"
        for mode in ("enforce", "agentenforce"):
            self.config["IntegrityMode"] = mode
            self.run_agent()
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.assertEqual(self.module.subprocess.Popen.call_count, 2)

    def test_legacy_preserves_existing_extracted_agent(self):
        self.config.pop("IntegrityMode")
        self.files[os.path.join(self.config["AgentFolder"], "bin", "Agent.Listener")] = b"old agent"
        self.run_agent()
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.module.subprocess.Popen.assert_called_once()

    def test_hash_verifier_checks_content_and_missing_file(self):
        self.files[self.agent] = b"agent"
        self.module.verify_file_sha256(self.agent, self.config["AgentDownloadSha256"])
        for path, expected in ((self.agent, "0" * 64), (self.script, self.config["EnableScriptSha256"])):
            with self.assertRaises(ValueError):
                self.module.verify_file_sha256(path, expected)

    def test_hash_verifier_reads_past_first_chunk(self):
        content = b"\x00\xff\r\n" * (256 * 1024) + b"tail\n"
        expected = "009a4614f0b673f2fa8e5c3e03c51c11b61e5f9a888b6c37bc42cda525f501d5"
        self.files[self.agent] = content
        self.module.verify_file_sha256(self.agent, expected)
        self.files[self.agent] = content[:-1] + b"x"
        with self.assertRaises(ValueError):
            self.module.verify_file_sha256(self.agent, expected)

    def test_public_contract_reads_protected_parameters_without_logging_them(self):
        settings = CompatDict(
            isPipelinesAgent=True,
            agentFolder=self.config["AgentFolder"],
            agentDownloadUrl=self.config["AgentDownloadUrl"],
            enableScriptDownloadUrl=self.config["EnableScriptDownloadUrl"],
            integrityMode="EnFoRcE",
            agentDownloadSha256=self.config["AgentDownloadSha256"],
            enableScriptSha256=self.config["EnableScriptSha256"],
        )
        self.module.handler_utility.get_public_settings.return_value = settings
        self.module.handler_utility.get_protected_settings.return_value = CompatDict(enableScriptParameters=self.config["EnableScriptParameters"])
        result = self.module.get_configuration_from_settings()
        self.assertEqual(result["IntegrityMode"], "enforce")
        for key in ("AgentDownloadSha256", "EnableScriptSha256", "EnableScriptParameters"):
            self.assertEqual(result[key], self.config[key])
        self.assertNotIn("protected-test-token", str(self.module.handler_utility.log.call_args_list))
        del settings["agentDownloadSha256"]
        settings["enableScriptSha256"] = "not-a-hash"
        result = self.module.get_configuration_from_settings()
        self.assertEqual(result["IntegrityMode"], "enforce")
        self.assertIsNone(result["AgentDownloadSha256"])
        self.assertEqual(result["EnableScriptSha256"], "not-a-hash")
        settings["integrityMode"] = " AgEnTeNfOrCe "
        self.assertEqual(self.module.get_configuration_from_settings()["IntegrityMode"], "agentenforce")
        del settings["integrityMode"]
        self.assertEqual(self.module.get_configuration_from_settings()["IntegrityMode"], "legacy")
        self.module.set_error_status_and_error_exit.assert_not_called()

    def test_invalid_public_integrity_modes_exit_before_download_or_execution(self):
        settings = CompatDict(
            isPipelinesAgent=True,
            agentFolder=self.config["AgentFolder"],
            agentDownloadUrl=self.config["AgentDownloadUrl"],
            enableScriptDownloadUrl=self.config["EnableScriptDownloadUrl"],
        )
        self.module.handler_utility.get_public_settings.return_value = settings
        self.module.handler_utility.get_protected_settings.return_value = CompatDict(enableScriptParameters=self.config["EnableScriptParameters"])
        for mode in (None, "", "unknown", 1, [], " "):
            with self.subTest(mode=mode):
                settings["integrityMode"] = mode
                with self.assertRaises(SystemExit):
                    self.module.get_configuration_from_settings()
        self.module.set_error_status_and_error_exit.assert_called()
        self.module.Util.url_retrieve.assert_not_called()
        self.module.subprocess.Popen.assert_not_called()


class TestPython3Integrity(IntegrityTests, unittest.TestCase):
    handler_name = "AzureRM"

    def test_agent_only_retains_unverified_bundled_fallback(self):
        self.config["IntegrityMode"] = "agentenforce"
        self.config.pop("EnableScriptSha256")
        self.downloaded_script = CompatError("Network unavailable")
        self.files[self.bundle] = b"unverified script"
        with patch.object(self.module, "verify_file_sha256", wraps=self.module.verify_file_sha256) as verify:
            self.run_agent()
            verify.assert_called_once_with(self.agent, self.config["AgentDownloadSha256"])
        self.assertEqual(self.module.Util.url_retrieve.call_count, 4)
        self.module.subprocess.Popen.assert_called_once()
        self.assertEqual(self.module.subprocess.Popen.call_args[0][0][1], self.bundle)
        self.module.shutil.copyfile.assert_not_called()

    def test_matching_bundled_fallback_uses_same_hash_and_original_path(self):
        self.downloaded_script = CompatError("Network unavailable")
        self.files[self.bundle] = b"script"
        with patch.object(self.module, "verify_file_sha256", wraps=self.module.verify_file_sha256) as verify:
            self.run_agent()
        self.assertEqual(verify.call_count, 2)
        verify.assert_any_call(self.bundle, self.config["EnableScriptSha256"])
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.module.subprocess.Popen.assert_called_once()
        self.module.shutil.copyfile.assert_not_called()
        self.assertEqual(self.module.subprocess.Popen.call_args[0][0][1], self.bundle)
        self.assertEqual(os.environ["VSTS_AGENT_VMEXT_FALLBACK_USED"], "true")

    def test_mismatched_bundle_is_not_copied_or_executed(self):
        self.downloaded_script = CompatError("Network unavailable")
        self.files[self.bundle] = b"wrong script"
        self.run_agent(expect_exit=True)
        self.assert_blocked()
        self.module.shutil.copyfile.assert_not_called()

    def test_mismatch_can_fall_back_only_to_matching_bundle(self):
        self.downloaded_script = b"bad download"
        self.files[self.bundle] = b"script"
        self.run_agent()
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.module.subprocess.Popen.assert_called_once()
        self.assertEqual(self.module.subprocess.Popen.call_args[0][0][1], self.bundle)

    def test_already_configured_keeps_original_skip(self):
        self.module.os.path.exists.return_value = True
        for mode in ("enforce", "agentenforce"):
            self.config["IntegrityMode"] = mode
            self.run_agent()
        self.module.Util.url_retrieve.assert_not_called()
        self.module.subprocess.Popen.assert_not_called()


class TestPython2Integrity(IntegrityTests, unittest.TestCase):
    handler_name = "AzureRM_python2"

    def test_configured_agent_keeps_original_bootstrap_skip(self):
        self.files[os.path.join(self.config["AgentFolder"], "bin", "Agent.Listener")] = b"configured agent"
        self.module.os.path.exists.return_value = True
        self.run_agent()
        self.module.set_error_status_and_error_exit.assert_not_called()
        self.module.subprocess.Popen.assert_called_once()

    def test_legacy_keeps_single_download_attempt_without_new_fallback(self):
        self.downloaded_script = CompatError("Network unavailable")
        self.files[self.bundle] = b"script"
        for mode in ("legacy", "agentenforce"):
            self.config["IntegrityMode"] = mode
            self.module.Util.url_retrieve.reset_mock()
            self.run_agent(expect_exit=True)
            self.assert_blocked()
            self.assertEqual(self.module.Util.url_retrieve.call_count, 2)
        self.module.shutil.copyfile.assert_not_called()


class TestPython3FileHash(unittest.TestCase):
    def test_fixed_binary_hash_and_trailing_mutation(self):
        module = load_handler("AzureRM")
        content = b"\x00\xff\r\n" * (256 * 1024) + b"tail\n"
        # Same independently checked binary vector as the Windows tests.
        expected = "009a4614f0b673f2fa8e5c3e03c51c11b61e5f9a888b6c37bc42cda525f501d5"
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "dummy-package")
            with open(path, "wb") as downloaded:
                downloaded.write(content)
            module.verify_file_sha256(path, expected)
            with open(path, "r+b") as downloaded:
                downloaded.seek(len(content) - 1)
                downloaded.write(b"x")
            with self.assertRaises(ValueError):
                module.verify_file_sha256(path, expected)


if __name__ == "__main__":
    unittest.main()
