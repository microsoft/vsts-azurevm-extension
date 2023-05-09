from __future__ import absolute_import
import time
from threading import RLock
from logging import getLogger, handlers
import logging
from .aria_log import AriaLog
            
class LogConfiguration(object):
    def __init__(self, log_level = logging.ERROR
                 , file_prefix = 'aria.log'
                 , file_max_size = 1024   # KB
                 , backup_count = 1024
                 , formatter = logging.Formatter("%(asctime)s [%(name)s][%(thread)d][%(process)d]:[%(levelname)s] %(filename)s:%(lineno)d %(message)s")
                 , file_handler = handlers.RotatingFileHandler):
        """!
        @brief Constructor for LogConfigurtion that enables logging traces inside the SDK, This must be used for debug puruse only, not for production
        @param log_level Minimum level of logging that will be printed (\b logging.ERROR for example)
        @param file_prefix Prefix of the file used to save the traces. It will be fallowed by time.strftime("%d_%m_%Y_%H_%M") (\b str)
        @param file_max_size Maximum size of the file in KB (\b int)
        @param backup_count  Maximum number of backup count (\b int)
        @param formatter Formatter used to print each trace. Change the default only if you know what you are doing and in debug mode only (\b logging.Formatter is an example)
        @param file_handler Type of file handler wanted (\b logging.handlers  contains some fileHandlers)
        """
        self.file_name = file_prefix
        self.log_level = log_level
        self.file_name += time.strftime("%d_%m_%Y_%H_%M")
        self.formatter = formatter
        self.file_max_size =  file_max_size * 1024  # In B
        self.backup_count = backup_count
        self.file_handler = file_handler

    @staticmethod
    def __init_log(logConf):
        from logging import handlers
        import logging
        if logConf.file_handler == handlers.RotatingFileHandler:
            logConf.file_handler = handlers.RotatingFileHandler(logConf.file_name, maxBytes=logConf.file_max_size, backupCount=logConf.backup_count)
            logConf.file_handler.setFormatter(logConf.formatter)
        AriaLog.aria_log.addHandler(logConf.file_handler)
        AriaLog.aria_log.setLevel(logConf.log_level)
