from __future__ import absolute_import
from .bond_types import PII

class AriaPiiExtension(object):
    def __init__(self):
        self.pii_properties = {}
   
    def get_bond_object(self):
        piiExtension = {}
        
        for key, (value, piiKind) in self.pii_properties.items():
            pii = PII()
            pii.kind = piiKind
            pii.raw_content = value
            pii.scrub_type = 1
            piiExtension[key] = pii
            
            return piiExtension
    
    @staticmethod
    def get_bond(pii_properties):
        piiExtension = {}
        
        for key, (value, piiKind) in pii_properties.items():
            pii = PII()
            pii.kind = piiKind
            pii.raw_content = value
            pii.scrub_type = 1
            piiExtension[key] = pii
            
        return piiExtension

