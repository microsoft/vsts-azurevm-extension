from __future__ import absolute_import
from .bond_types import ClientToCollectorRequest, DataPackage
from .utilities import AriaUtilities
from .bond import AriaBondFast
import sys

class BatchingPackage(object):
    def __init__(self, tenant, size):
        self.tenant = tenant
        self.package_to_serialize = ClientToCollectorRequest()
        self.package_to_serialize.data_packages = [DataPackage()]
        self.package_to_serialize.data_packages[0].data_package_id = AriaUtilities.generate_guid()
        self.package_to_serialize.data_packages[0].source = "AST_Default_Source"
        self.package_to_serialize.data_packages[0].timestamp = AriaUtilities.get_current_time_epoch_ms()
        self.package_to_serialize.data_packages[0].schema_version = 1
        self.package_to_serialize.data_packages[0].records = []
        if sys.version_info[0] < 3:
            self.serialized = ''
        else:
            self.serialized = b''
        self.records = 0
        self.records_list = []
        self.size = size
        self.max_size_reached = False
        
    def open_batching(self):
        self.serialized = AriaBondFast.SerializeStart(self.package_to_serialize, self.records) + self.serialized
    
    def close_batching(self):
        self.serialized += AriaBondFast.SerializeStop(self.package_to_serialize)