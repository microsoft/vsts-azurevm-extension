class User(object):
    def __init__(self, username = "" , ui_version = ""):
        self.username = username
        self.ui_version = ui_version
               
class PII(object):
    def __init__(self, scrub_type = 0, kind = 0, raw_content = ""):
        self.scrub_type = scrub_type
        self.kind = kind
        self.raw_content = raw_content
        
class Record(object):
    def __init__(self, 
                 record_id = "", \
                 timestamp = 0,
                 configuration_ids = None,
                 record_type_str = "",
                 event_type = "",
                 extension = None,
                 context_ids = None,
                 initiating_user_composite = None,
                 record_type_int = 0,
                 pii_extensions = None):
        self.record_id = record_id
        self.timestamp = timestamp
        self.configuration_ids = configuration_ids
        self.type = record_type_str
        self.event_type = event_type
        self.extension = extension
        self.context_ids = context_ids
        self.initiating_user_composite = initiating_user_composite
        self.record_type_int = record_type_int
        self.pii_extensions = pii_extensions
        
class DataPackage(object):
    def __init__(self,
                 data_package_type = "", \
                 source = "", \
                 version = "", \
                 ids = None, \
                 data_package_id = "", \
                 timestamp = 0, \
                 schema_version = 0, \
                 records = None):
        self.data_package_type = data_package_type
        self.source = source
        self.version = version
        self.ids = ids
        self.data_package_id = data_package_id
        self.timestamp = timestamp
        self.schema_version = schema_version
        self.records = records
    
class ClientToCollectorRequest(object):
    def __init__(self,
                 data_packages = None, \
                 request_retry_count = 0):
        self.data_packages = data_packages
        self.request_retry_count = request_retry_count
    
    