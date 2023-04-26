from __future__ import absolute_import
from .bond import AriaBond

class BatchingRecord(object):
    def __init__(self, tenant):
        self.tenant = tenant
        self.record = b''
        self.sequence_id = 0
        self.bond_failed = False

    def batch_record(self):
        self.record = AriaBond.serialize_static(self.record)
        self.size = len(self.record)
        