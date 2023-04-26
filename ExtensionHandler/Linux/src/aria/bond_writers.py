from __future__ import absolute_import
from .bond_types import *
from .compact_binary_protocol import *
import sys

class BondSerializer(object):
    
    def SerializeUser(self, writer, value, is_base):
        
        if value.username != "":
            writer.WriteFieldBegin(9, 1, None)
            writer.WriteString(value.username)
            
        if value.ui_version != "":
            writer.WriteFieldBegin(9, 3, None)
            writer.WriteString(value.ui_version)
        
        writer.WriteStructEnd(is_base)
    
    def SerializePII(self, writer, value, is_base):
        
        if value.scrub_type != 0:
            writer.WriteFieldBegin(16, 1, None)
            writer.WriteInt32(value.scrub_type)
            
        if value.kind != 0:
            writer.WriteFieldBegin(16, 2, None)
            writer.WriteInt32(value.kind)
        
        if value.raw_content != 0:
            writer.WriteFieldBegin(9, 3, None)
            writer.WriteString(value.raw_content)
                
        writer.WriteStructEnd(is_base)
    
    def SerializeRecord(self, writer, value, is_base):
    
        if value.record_id != 0:
            writer.WriteFieldBegin(9 , 1, None)
            writer.WriteString(value.record_id)
    
        if value.timestamp != 0:
            writer.WriteFieldBegin(17 , 3, None)
            writer.WriteInt64(value.timestamp)
    
        if value.configuration_ids != None and len(value.configuration_ids) != 0:
            writer.WriteFieldBegin(13 , 4, None)
            writer.WriteMapContainerBegin(len(value.configuration_ids), 9 , 9 )
            for item in value.configuration_ids:
                writer.WriteString(item)
                writer.WriteString(value.configuration_ids[item])
    
        if value.type != "":
            writer.WriteFieldBegin(9 , 5, None)
            writer.WriteString(value.type)
        
        if value.event_type != "":
            writer.WriteFieldBegin(9 , 6, None)
            writer.WriteString(value.event_type)
    
        if value.extension != None and len(value.extension) != 0:
            writer.WriteFieldBegin(13 , 13, None)
            writer.WriteMapContainerBegin(len(value.extension), 9 , 9 )
            for item in value.extension:
                writer.WriteString(item)
                writer.WriteString(value.extension[item])
        
        if value.context_ids != None and len(value.context_ids) != 0:
            writer.WriteFieldBegin(13 , 19, None)
            writer.WriteMapContainerBegin(len(value.context_ids), 9 , 9 )
            for item in value.context_ids:
                writer.WriteString(item)
                writer.WriteString(value.context_ids[item])
    
        if value.initiating_user_composite != None:
            writer.WriteFieldBegin(10 , 21, None)
            self.__Serialize(writer, value.initiating_user_composite, False)
    
        if value.record_type_int != 0:
            writer.WriteFieldBegin(16 , 24, None)
            writer.WriteInt32(value.record_type_int)
    
        if value.pii_extensions != None and len(value.pii_extensions) != 0:
            writer.WriteFieldBegin(13 , 30, None)
            writer.WriteMapContainerBegin(len(value.pii_extensions), 9 , 10 )
            for item in value.pii_extensions:
                writer.WriteString(item)
                self.__Serialize(writer, value.pii_extensions[item], False)
            
        writer.WriteStructEnd(is_base)
    
    def SerializeDataPackage(self, writer, value, is_base):
    
        if value.data_package_type != "":
            writer.WriteFieldBegin(9, 1, None)
            writer.WriteString(value.data_package_type)
    
        if value.source != "":
            writer.WriteFieldBegin(9, 2, None)
            writer.WriteString(value.source)
    
        if value.version != "":
            writer.WriteFieldBegin(9, 3, None)
            writer.WriteString(value.version)
    
        if value.ids != None and len(value.ids) != 0:
            writer.WriteFieldBegin(13, 4, None)
            writer.WriteMapContainerBegin(len(value.ids), 9 , 9)
            for item in value.ids:
                writer.WriteString(item)
                writer.WriteString(value.ids[item])
            writer.WriteContainerEnd()
    
        if value.data_package_id != "":
            writer.WriteFieldBegin(9, 5, None)
            writer.WriteString(value.data_package_id)
    
        if value.timestamp != 0:
            writer.WriteFieldBegin(17 , 6, None)
            writer.WriteInt64(value.timestamp)
    
        if value.schema_version != 0:
            writer.WriteFieldBegin(16, 7, None)
            writer.WriteInt32(value.schema_version)
    
        if value.records != None and len(value.records) != 0:
            writer.WriteFieldBegin(11, 8, None)
            writer.WriteContainerBegin(len(value.records), 10 )
            for item in value.records:
                self.__Serialize(writer, item, False)
    
        writer.WriteStructEnd(is_base)
    
    def SerializeClientToCollectorRequest(self, writer, value, is_base):
    
        if value.data_packages != None:
            writer.WriteFieldBegin(11 , 1, None)
            writer.WriteContainerBegin(len(value.data_packages), 10 )
            for item in value.data_packages:
                self.__Serialize(writer, item, False)
    
        if value.request_retry_count != 0:
            writer.WriteFieldBegin(16 , 2, None)
            writer.WriteInt32(value.request_retry_count)
    
        writer.WriteStructEnd(is_base)
        
    def SerializeClientToCollectorRequestStart(self, writer, value, records, is_base):
        if value.data_packages != None:
            writer.WriteFieldBegin(11 , 1, None)
            writer.WriteContainerBegin(len(value.data_packages), 10 )
            for item in value.data_packages:
                self.SerializeDataPackageStart(writer, item, records, False)
    
    def SerializeClientToCollectorRequestEnd(self, writer, value, is_base):
        if value.request_retry_count != 0:
            writer.WriteFieldBegin(16 , 2, None)
            writer.WriteInt32(value.request_retry_count)
    
        writer.WriteStructEnd(is_base)
    
    def SerializeDataPackageStart(self, writer, value, records, is_base):    
        if value.data_package_type != "":
            writer.WriteFieldBegin(9 , 1, None)
            writer.WriteString(value.data_package_type)
    
        if value.source != "":
            writer.WriteFieldBegin(9 , 2, None)
            writer.WriteString(value.source)
    
        if value.version != "":
            writer.WriteFieldBegin(9 , 3, None)
            writer.WriteString(value.version)
    
        if value.ids != None and len(value.ids) != 0:
            writer.WriteFieldBegin(13 , 4, None)
            writer.WriteMapContainerBegin(len(value.ids), 9 , 9)
            for item in value.ids:
                writer.WriteString(item)
                writer.WriteString(value.ids[item])
            writer.WriteContainerEnd()
    
        if value.data_package_id != "":
            writer.WriteFieldBegin(9 , 5, None)
            writer.WriteString(value.data_package_id)
    
        if value.timestamp != 0:
            writer.WriteFieldBegin(17 , 6, None)
            writer.WriteInt64(value.timestamp)
    
        if value.schema_version != 0:
            writer.WriteFieldBegin(16 , 7, None)
            writer.WriteInt32(value.schema_version)
    
        writer.WriteFieldBegin(11 , 8, None)
        writer.WriteContainerBegin(records, 10 )
    
    def SerializeDataPackageStartEnd(self, writer, value, is_base):
        writer.WriteStructEnd(is_base)
    
    def __Serialize(self, writer, value, is_base):
        {
        'User' : self.SerializeUser,
        'AriaBondTypes.User' : self.SerializeUser,
        'PII': self.SerializePII,
        'AriaBondTypes.PII': self.SerializePII,
        'Record': self.SerializeRecord,
        'AriaBondTypes.Record': self.SerializeRecord,
        'DataPackage': self.SerializeDataPackage,
        'AriaBondTypes.DataPackage': self.SerializeDataPackage,
        'ClientToCollectorRequest': self.SerializeClientToCollectorRequest,
        'AriaBondTypes.ClientToCollectorRequest': self.SerializeClientToCollectorRequest
        }[type(value).__name__](writer, value, is_base)

    def SerializeSize(self, writer, value, is_base = False):
        self.__Serialize(writer, value, is_base)
        return len(writer._output) + writer._output_string_size
    
    def Serialize(self, writer, value, is_base = False):
        self.__Serialize(writer, value, is_base)
        return self.GetOutput(writer)
    
    def GetOutput(self, writer):
        if sys.version_info[0] < 3:
            return ''.join(str(chr(i)) if (type(i) != str and type(i) != bytes) else i for i in writer._output)
        else:
            return b''.join(bytes(chr(i) if type(i) != str else i, 'latin1') if type(i) != bytes else  i for i in writer._output)
        
    def EmptyBuffer(self, writer):
        del writer._output[:]
        writer._output_string_size = 0