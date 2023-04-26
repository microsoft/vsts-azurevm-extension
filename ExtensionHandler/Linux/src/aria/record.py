from __future__ import absolute_import
from .bond_types import Record
from .utilities import AriaUtilities
from .extension import AriaExtension
from .pii_extension import AriaPiiExtension

class AriaRecord(object):
    def __init__(self, eventType, type="custom", recordType=1):
        self.id = AriaUtilities.generate_guid()
        self.type = type
        self.event_type = eventType
        self.time_stamp = AriaUtilities.get_current_time_epoch_ms()
        self.record_type = 1
        self.properties = {}
        self.pii_properties = {}
        self.init_id = ""
        self.sequence_id = 0
        self.retry_count = 0

    def get_bond_object(self):
        bond_record = Record()
        bond_record.record_id = self.id
        bond_record.type = self.type
        bond_record.event_type = self.event_type
        bond_record.record_type_int = self.record_type
        bond_record.timestamp = self.time_stamp
        aria_extension = AriaExtension("", self.event_type, self.init_id, self.sequence_id, self.time_stamp)
        aria_extension.properties = self.properties
        bond_record.extension = aria_extension.get_bond_object()
        
        if (len(list(self.pii_properties.items())) > 0):
            aria_pii_extension = AriaPiiExtension()
            aria_pii_extension.pii_properties = self.pii_properties
            bond_record.pii_extensions = aria_pii_extension.get_bond_object()

        return bond_record