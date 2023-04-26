from uuid import uuid1
from datetime import datetime
from time import time
from .log_config import AriaLog
from io import BytesIO
from gzip import GzipFile
import sys

if sys.version_info[0] < 3:
    from StringIO import StringIO
            
class AriaUtilities(object):
    @staticmethod
    def generate_guid():
        return str(uuid1()).lower()
    
    @staticmethod
    def get_utc_time():
        return str(datetime.utcnow().isoformat())

    @staticmethod
    def get_current_time_epoch_ms():
        return int(time()) * 1000

    @staticmethod
    def convert_ms_to_isoformat(time_in_ms):
        date_time = datetime.fromtimestamp(time_in_ms / 1000.0)
        return str(date_time.isoformat())

    @staticmethod
    def gzip_compress(input_buffer):
        try:
            string_buffer = BytesIO() if sys.version_info[0] >= 3 else StringIO()
            gzip_file = GzipFile(fileobj=string_buffer, mode=u'w', compresslevel = 6)
            gzip_file.write(input_buffer)
            gzip_file.close()
            return string_buffer.getvalue()

        except Exception as e :
            AriaLog.aria_log.warning("Compressing failed" + str(sys.exc_info()[0]))
            return None
