from __future__ import absolute_import
from .compact_binary_protocol import CompactBinaryProtocolWriter
from . import bond_writers
from threading import RLock
from .log_config import AriaLog
from sys import exc_info

class AriaBond(object):
    writer = None
    serial = None
    initialized = False
    serialize_lock = RLock()
    
    def __init__(self):
        self.writer = CompactBinaryProtocolWriter()
        self.serial = bond_writers.BondSerializer()
        self.writer_lock = RLock()
    
    def serialize(self, record):
        serialized_record_buffer = self.serial.Serialize(self.writer, record)
        self.serial.EmptyBuffer(self.writer)
        return serialized_record_buffer

    @staticmethod
    def init_static():
        with AriaBond.serialize_lock:
            if AriaBond.initialized == False:
                AriaBond.writer = CompactBinaryProtocolWriter()
                AriaBond.serial = bond_writers.BondSerializer()
                AriaBond.initialized = True
        
    @staticmethod
    def serialize_static(record):
        with AriaBond.serialize_lock:
            serialized_record_buffer = AriaBond.serial.Serialize(AriaBond.writer, record)
            AriaBond.serial.EmptyBuffer(AriaBond.writer)
            return serialized_record_buffer
    
    def serialize_size(self, record):
        with AriaBond.serialize_lock:
            serialized_record_size = self.serial.SerializeSize(self.writer, record)
            self.serial.EmptyBuffer(self.writer)
            return serialized_record_size
    
        
class AriaBondFast(object):    
    writer = CompactBinaryProtocolWriter()
    serial = bond_writers.BondSerializer()
    writer_lock = RLock()
    
    @staticmethod
    def SerializeStart(record, records_count):
        try:
            with AriaBondFast.writer_lock:
                AriaBondFast.serial.SerializeClientToCollectorRequestStart(AriaBondFast.writer, record, records_count, False)
                serialized_record_buffer = AriaBondFast.serial.GetOutput(AriaBondFast.writer)
                AriaBondFast.serial.EmptyBuffer(AriaBondFast.writer)
                return serialized_record_buffer
        except:
            AriaLog.aria_log.warning("SerializeStart failed" + str(exc_info()[0]))

    @staticmethod
    def SerializeStop(record):
        try:
            with AriaBondFast.writer_lock:
                serialized_record_buffer = AriaBondFast.serial.SerializeDataPackageStartEnd(AriaBondFast.writer, record, False)
                serialized_record_buffer = AriaBondFast.serial.GetOutput(AriaBondFast.writer)
                AriaBondFast.serial.EmptyBuffer(AriaBondFast.writer)
                
                AriaBondFast.serial.SerializeClientToCollectorRequestEnd(AriaBondFast.writer, record, False)
                serialized_record_buffer += AriaBondFast.serial.GetOutput(AriaBondFast.writer)
                AriaBondFast.serial.EmptyBuffer(AriaBondFast.writer)
                return serialized_record_buffer
        except:
            AriaLog.aria_log.warning("SerializeStop failed" + str(exc_info()[0]))

def SerializeEvents(record_list):
    try:
        CompactBinaryProtocolWriter.InitGenerated()
        AriaBond.init_static()
    except:
        for record in record_list:
            record.bond_failed = True
        return record_list
    
    for batching_record in record_list:
        try:
            batching_record.batch_record()
        except:
            batching_record.bond_failed = True
    return record_list
