from logging import getLogger, handlers
from threading import RLock

class AriaLog(object):
    aria_log = getLogger("aria")
    aria_log_lock = RLock()