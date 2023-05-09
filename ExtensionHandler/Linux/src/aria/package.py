from __future__ import absolute_import
from .utilities import AriaUtilities
from .bond_types import DataPackage

class AriaPackage(object):
    def __init__(self, source="AST_Default_Source"):
        self.datapackage_id = AriaUtilities.generate_guid()
        self.source = source
        self.time_stamp = AriaUtilities.get_utc_time()
        self.schema_version = 1
        self.records = []

    def get_bond_object(self):
        bond_package = DataPackage()
        bond_package.data_package_id = self.datapackage_id
        bond_package.source = self.source
        bond_package.timestamp = AriaUtilities.get_current_time_epoch_ms()
        bond_package.schema_version = self.schema_version
        bond_package.records = self.records
        return bond_package