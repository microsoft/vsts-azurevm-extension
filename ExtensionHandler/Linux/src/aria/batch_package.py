from __future__ import absolute_import
from threading import RLock
import aria.log_manager
from .batching_package import BatchingPackage
from .log_config import AriaLog
from sys import exc_info
from .subscribe import SubscribeStatus
from .stats_manager import StatsConstants

class BatchPackage(object):
    queue = []          
    queue_to_send = []  
    queue_to_send_lock = RLock()
    queue_lock = RLock()
    
    @staticmethod
    def add_records(record_list):
        ''' a list of BatchingRecords '''

        AriaLog.aria_log.debug("Put records into packages")
        with BatchPackage.queue_lock:
            for batching_record in record_list:
                if batching_record.bond_failed == True:
                    AriaLog.aria_log.debug("Bond failed, event dropped, event_sequence_id=" + str(batching_record.sequence_id))
                    aria.log_manager.LogManagerImpl.stats_manager.records_bond_failed(batching_record.tenant, 1)
                    
                    if StatsConstants.stats_tenant_token != batching_record.tenant:
                        aria.log_manager.LogManagerImpl.decrement_events_in_memory(1)
                        
                    aria.log_manager.LogManagerImpl.subscribers.update(batching_record.tenant, [batching_record.sequence_id], SubscribeStatus.BOND_FAILED)
                    aria.log_manager.LogManagerImpl.stats_manager.events_dropped(batching_record.tenant, 1)
                else:
                    try:
                        if aria.log_manager.LogManagerImpl.configuration.MAX_SIZE_ALLOWED < batching_record.size:
                            AriaLog.aria_log.debug("Record reached the maximum size allowed")
                            AriaLog.aria_log.debug("Max size=" + str(aria.log_manager.LogManagerImpl.configuration.MAX_SIZE_ALLOWED) + ", record_size=" + str(batching_record.size))
                            
                            if StatsConstants.stats_tenant_token != batching_record.tenant:
                                aria.log_manager.LogManagerImpl.decrement_events_in_memory(1)
                            
                            aria.log_manager.LogManagerImpl.stats_manager.events_dropped(batching_record.tenant, 1)
                            aria.log_manager.LogManagerImpl.stats_manager.records_dropped_status(batching_record.tenant, 1, "event_to_big")
                            aria.log_manager.LogManagerImpl.subscribers.update(batching_record.tenant, [batching_record.sequence_id], SubscribeStatus.EVENT_TO_BIG)
                            continue
                        
                        found_tenant = False
                        for index in range(len(BatchPackage.queue)):
                            if batching_record.tenant == BatchPackage.queue[index].tenant:
                                if BatchPackage.queue[index].size + batching_record.size < aria.log_manager.LogManagerImpl.configuration.MAX_SIZE_ALLOWED:
                                    found_tenant = True
                                    BatchPackage.queue[index].records += 1
                                    BatchPackage.queue[index].serialized += batching_record.record
                                    BatchPackage.queue[index].size += batching_record.size
                                    BatchPackage.queue[index].records_list.append(batching_record.sequence_id)
                                    break
                                else:
                                    BatchPackage.queue[index].max_size_reached = True
                                    
                        if found_tenant == False:
                            AriaLog.aria_log.debug("New package was created")
                            package = BatchingPackage(batching_record.tenant, batching_record.size)
                            package.serialized += batching_record.record
                            package.records = 1
                            package.records_list.append(batching_record.sequence_id)
                            BatchPackage.queue.append(package)
                    except:
                        if aria.log_manager.LogManagerImpl.stats_manager != None:
                            if StatsConstants.stats_tenant_token != batching_record.tenant:
                                aria.log_manager.LogManagerImpl.decrement_events_in_memory(1)
                            
                            aria.log_manager.LogManagerImpl.subscribers.update(batching_record.tenant, [batching_record.sequence_id], SubscribeStatus.PATCHING_FAILED)
                            aria.log_manager.LogManagerImpl.stats_manager.records_dropped_status(batching_record.tenant, 1, "packaging_failed")
                        AriaLog.aria_log.warning("BatchPackage failed " + str(exc_info()[0]))
                # Feed the sender
            BatchPackage.feed_sender()
            
    @staticmethod
    def feed_sender():
        from .batcher import Batcher
        
        #Try to send the packages with 3MB
        if len(Batcher.out_queue) <  aria.log_manager.LogManagerImpl.configuration.TCP_CONNECTIONS:
            with BatchPackage.queue_lock:
                packages_index_to_remove = []
                for index in range(len(BatchPackage.queue)):
                    if BatchPackage.queue[index].max_size_reached == True:
                        AriaLog.aria_log.debug("Package has reached maximum size, moved into the sender queue")
                        packages_index_to_remove.append(index)
                        BatchPackage.queue[index].open_batching()
                        BatchPackage.queue[index].close_batching()
                        with BatchPackage.queue_to_send_lock:
                            BatchPackage.queue_to_send.append(BatchPackage.queue[index])
            
                if len(packages_index_to_remove) > 0:
                    reverse_list = reversed(packages_index_to_remove)
                    for index in reverse_list:
                        del BatchPackage.queue[index]
        
            # Try to fill out the queue to not starve the open connection
            with BatchPackage.queue_lock:
                packages_index_to_remove = []
                for index in range(len(BatchPackage.queue)):
                    with Batcher.out_queue_lock:
                        if len(Batcher.out_queue) < aria.log_manager.LogManagerImpl.configuration.TCP_CONNECTIONS or Batcher.is_flushed:
                            AriaLog.aria_log.debug("Package put into the sender queue")
                            BatchPackage.queue[index].open_batching()
                            BatchPackage.queue[index].close_batching()
                            Batcher.out_queue.append(BatchPackage.queue[index])
                            packages_index_to_remove.append(index)
                        
                if len(packages_index_to_remove) > 0:
                    reverse_list = reversed(packages_index_to_remove)
                    for index in reverse_list:
                        del BatchPackage.queue[index]
    
    @staticmethod
    def flush_packages():
        from .batcher import Batcher
        with BatchPackage.queue_lock:
            for index in range(len(BatchPackage.queue)):
                with Batcher.out_queue_lock:
                    AriaLog.aria_log.debug("Flush_packages Package put into the sender queue")
                    BatchPackage.queue[index].open_batching()
                    BatchPackage.queue[index].close_batching()
                    Batcher.out_queue.append(BatchPackage.queue[index])
        
        with BatchPackage.queue_to_send_lock:
            with Batcher.out_queue_lock:
                for package in BatchPackage.queue_to_send:
                    AriaLog.aria_log.debug("Flush_packages Package put into the sender queue")
                    Batcher.out_queue.append(package)

    @staticmethod
    def remove_package_from_ready_queue():
        with BatchPackage.queue_to_send_lock:
            if len(BatchPackage.queue_to_send) > 0:
                package = BatchPackage.queue_to_send[0]
                del BatchPackage.queue_to_send[0]
                AriaLog.aria_log.debug("Remove 3 MB package")
                return package
            return None
    
    @staticmethod
    def remove_package_from_queue():
        with BatchPackage.queue_lock:
            if len(BatchPackage.queue) > 0:
                package = BatchPackage.queue[0]
                del BatchPackage.queue[0]
                AriaLog.aria_log.debug("Remove a regular package")
                return package
            return None
            