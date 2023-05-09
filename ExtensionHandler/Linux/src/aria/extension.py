from __future__ import absolute_import
from .utilities import AriaUtilities

class AriaExtension(object):
    def __init__(self, source, name, init_id, sequence_id, time_stamp):
        self.name = name
        self.source = source if source else "Ast_Default_Source"
        self.init_id = init_id
        self.sequence_id = sequence_id
        self.time_stamp = time_stamp
        self.properties = {}
   
    def get_bond_object(self):
        extension = {}

        extension["EventInfo.Source"] = self.source
        extension["EventInfo.Name"] = self.name
        extension["EventInfo.Time"] = AriaUtilities.convert_ms_to_isoformat(self.time_stamp)
        extension["EventInfo.InitId"] = self.init_id
        extension["EventInfo.Sequence"] = str(self.sequence_id)
        
        for key, value in self.properties.items():
            extension[key] = value

        return extension
    
    @staticmethod
    def get_bond(source, name, init_id, sequence_id, time_stamp, properties):
        extension = {}
        extension["EventInfo.Source"] = source if source else "Ast_Default_Source"
        extension["EventInfo.Name"] = name
        extension["EventInfo.Time"] = AriaUtilities.convert_ms_to_isoformat(time_stamp)
        extension["EventInfo.InitId"] = init_id
        extension["EventInfo.Sequence"] = str(sequence_id)
        
        for key, value in properties.items():
            extension[key] = value

        return extension
