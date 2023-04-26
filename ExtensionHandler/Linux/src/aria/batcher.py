from __future__ import absolute_import
from time import sleep
from threading import Thread
from threading import RLock
import aria.log_manager
#from . import log_manager
from . import batch_package
import multiprocessing
from .bond import SerializeEvents
from .log_config import AriaLog
from sys import exc_info
from .subscribe import SubscribeStatus
from . import stats_manager
from .stats_manager import StatsConstants

class Batcher(object):
    out_queue = []
    in_queue = []
    out_queue_lock = RLock()
    in_queue_lock = RLock()
    batcher_thread_running = False
    sender_thread_running = False
    sender_thread_lazy_running = False
    batcher_lazy_thread_running= False
    bathcer_thread_list = []
    is_flushed = False
    
    @staticmethod
    def clean_up():
        AriaLog.aria_log.info("Clean up")
        Batcher.out_queue = []
        Batcher.in_queue = []
        Batcher.out_queue_lock = RLock()
        Batcher.in_queue_lock = RLock()
        Batcher.batcher_thread_running = False
        Batcher.sender_thread_running = False
        Batcher.sender_thread_lazy_running = False
        Batcher.batcher_lazy_thread_running= False
        Batcher.is_flushed = False
    
    @staticmethod
    def stop_and_clean_up():
        AriaLog.aria_log.info("Stop")
        try:
            Batcher.clean_up()
            for i in Batcher.bathcer_thread_list:
                if i != None:
                    i.join(1)
            Batcher.bathcer_thread_list = None
            return True
        except:
            AriaLog.aria_log.warning("Stop failed " + str(exc_info()[0]))
            return False
    
    @staticmethod
    def flush():
        AriaLog.aria_log.info("Flush was called")
        Batcher.is_flushed = True
        Batcher.send_all_remaining_events()
        # Turn all threads off
        Batcher.batcher_thread_running = False
        Batcher.batcher_lazy_thread_running = False
        Batcher.sender_thread_running = False
        Batcher.sender_thread_lazy_running = False

        # wait for all threads to be done
        for i in Batcher.bathcer_thread_list:
            if i != None:
                i.join(0.1)

        Batcher.bathcer_thread_list = None

        Batcher.sender_thread.join(0.1)
        Batcher.sender_thread_lazy.join(0.1)
        Batcher.sender_thread = None
        Batcher.sender_thread_lazy = None
        # Send all remaining events to packages
        batch_package.BatchPackage.flush_packages()
        return True
        
    @staticmethod
    def send_all_remaining_events():
        # SDK doesn't received any more 
        AriaLog.aria_log.info("SDK was stopped and it's sending all the remaining events")
        try:
            records = Batcher.remove_record_from_in_leazy(len(Batcher.in_queue))
            if records != None:
                records_size = len(records)
                AriaLog.aria_log.info("Number of remaining events " + str(records_size))
                for i in range(0, records_size, 200):
                    end = i + 200 if i + 200 < records_size else records_size
                    if aria.log_manager.LogManagerImpl.configuration.PROCESS_NUMBER > 0:
                        aria.log_manager.LogManagerImpl.pool_process.apply_async(SerializeEvents, args=(records[i:end],), callback = batch_package.BatchPackage.add_records).get()
                    else:
                        batch_package.BatchPackage.add_records(SerializeEvents(records[i:end]))
        except:
            AriaLog.aria_log.warning("SDK was stopped and it's sending all the remaining events failed " + str(exc_info()[0]))
            
    @staticmethod
    def define_threads():
        # Make sure we start with a clean state
        Batcher.sender_thread = None
        Batcher.sender_thread_lazy = None

        AriaLog.aria_log.info("Define batcher threads")
        try:
            Batcher.sender_thread = Thread(target = Batcher.__run_sender)
            Batcher.sender_thread_lazy = Thread(target = Batcher.__run_sender_lazy)
        except:
            AriaLog.aria_log.warning("Define batcher threads " + str(exc_info()[0]))
            
    @staticmethod
    def start_sender_lazy_thread():
        AriaLog.aria_log.info("Start lazy thread")
        Batcher.sender_thread_lazy_running = True
        Batcher.sender_thread_lazy.start()

    @staticmethod    
    def start_batcher_thread():
        AriaLog.aria_log.info("Start batcher thread")
        Batcher.batcher_thread_running = True
        Batcher.batcher_lazy_thread_running = True
        Batcher.bathcer_thread_list = []
        batcher_th = None

        if aria.log_manager.LogManagerImpl.configuration.PROCESS_NUMBER > 0:
            AriaLog.aria_log.debug("Bond serialize process number=" + str(aria.log_manager.LogManagerImpl.configuration.PROCESS_NUMBER))
            for i in range(aria.log_manager.LogManagerImpl.configuration.PROCESS_NUMBER):
                th = Thread(target = Batcher.__run_batcher)
                th.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON
                th.start()
                Batcher.bathcer_thread_list.append(th)
                AriaLog.aria_log.debug("Batcher started number" + str(i))
                
            batcher_th = Thread(target = Batcher.__run_batcher_lazy)
            batcher_th.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON 
            batcher_th.start()
            Batcher.bathcer_thread_list.append(batcher_th)
        else:
            th = Thread(target=Batcher.__run_batcher_thread)
            th.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON
            th.start()
            Batcher.bathcer_thread_list.append(batcher_th)

            th = Thread(target=Batcher.__run_batcher_lazy_thread)
            th.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON
            th.start()
            Batcher.bathcer_thread_list.append(batcher_th)
    
    @staticmethod
    def start_sender_thread():
        AriaLog.aria_log.info("Start sender thread")
        Batcher.sender_thread_running = True
        Batcher.sender_thread.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON 
        Batcher.sender_thread.start()

    @staticmethod
    def __run_batcher_thread():
        AriaLog.aria_log.info("__run_batcher_thread started")
        while Batcher.batcher_thread_running == True:
            records = Batcher.remove_records_from_in(aria.log_manager.LogManagerImpl.configuration.MAX_EVENTS_TO_BATCH)
            if records != None:
                AriaLog.aria_log.debug("Processing records" + " Records=" + str(len(records)))
                batch_package.BatchPackage.add_records(SerializeEvents(records))
            sleep(aria.log_manager.LogManagerImpl.configuration.BATCHER_TIMER)
    
    @staticmethod
    def __run_batcher():
        AriaLog.aria_log.info("__run_batcher started")
        while Batcher.batcher_thread_running == True:
            records = Batcher.remove_records_from_in(aria.log_manager.LogManagerImpl.configuration.MAX_EVENTS_TO_BATCH)
            if records != None:
                AriaLog.aria_log.debug("Processing records async" + " Records=" + str(len(records)))
                aria.log_manager.LogManagerImpl.pool_process.apply_async(SerializeEvents, args=(records,), callback = batch_package.BatchPackage.add_records).get()
            sleep(aria.log_manager.LogManagerImpl.configuration.BATCHER_TIMER)
    
    @staticmethod
    def __run_batcher_lazy_thread():
        AriaLog.aria_log.info("__run_batcher_lazy_thread started")
        while Batcher.batcher_lazy_thread_running == True:
            records = Batcher.remove_record_from_in_leazy(aria.log_manager.LogManagerImpl.configuration.MAX_EVENTS_TO_BATCH)
            if records != None:
                AriaLog.aria_log.debug("Processing records" + " Records=" + str(len(records)))
                batch_package.BatchPackage.add_records(SerializeEvents(records))
            sleep(aria.log_manager.LogManagerImpl.configuration.LAZY_BATCHER_TIMER)
            
    @staticmethod
    def __run_batcher_lazy():
        AriaLog.aria_log.info("__run_batcher_lazy started")
        while Batcher.batcher_lazy_thread_running == True:
            records = Batcher.remove_record_from_in_leazy(aria.log_manager.LogManagerImpl.configuration.MAX_EVENTS_TO_BATCH)
            if records != None:
                AriaLog.aria_log.debug("Processing records async" + " Records=" + str(len(records)))
                aria.log_manager.LogManagerImpl.pool_process.apply_async(SerializeEvents, args=(records,), callback = batch_package.BatchPackage.add_records).get()
            sleep(aria.log_manager.LogManagerImpl.configuration.LAZY_BATCHER_TIMER)
    
    @staticmethod
    def __run_sender():
        ''' Only sends 3MB Packages'''
        while Batcher.sender_thread_running == True:
            package = batch_package.BatchPackage.remove_package_from_ready_queue()
            if package != None:
                with Batcher.out_queue_lock:
                    Batcher.out_queue.append(package)
                AriaLog.aria_log.debug("Put a 3MB package in the queue to send")    
            else:
                sleep(aria.log_manager.LogManagerImpl.configuration.SENDER_TIMER)
    
    @staticmethod
    def __run_sender_lazy():
        ''' This adds all the events and send them to be batched per tenant ID'''
        while Batcher.sender_thread_lazy_running == True:
            package = batch_package.BatchPackage.remove_package_from_queue()
            if package != None:
                package.open_batching()
                package.close_batching()
                with Batcher.out_queue_lock:
                    Batcher.out_queue.append(package)
                AriaLog.aria_log.debug("Put any package there is in the queue in queue to send")
            sleep(aria.log_manager.LogManagerImpl.configuration.SENDER_LAZY_TIMER)
    
    @staticmethod
    def add_record(tenant, record):        
        with Batcher.in_queue_lock:
            Batcher.in_queue.append(record)
        if StatsConstants.stats_tenant_token != tenant:
            aria.log_manager.LogManagerImpl.increment_events_in_memory(1)

    @staticmethod        
    def remove_record_from_in_leazy(count):    
        with Batcher.in_queue_lock:
            if len(Batcher.in_queue) != 0:
                if count > len(Batcher.in_queue):
                    count = len(Batcher.in_queue)
                AriaLog.aria_log.debug("Lazy Removed records from the queue Records=" + str(count))
                records = Batcher.in_queue[:count]
                del Batcher.in_queue[:count]
                return records
            return None
        
    @staticmethod
    def remove_records_from_in(count):
        with Batcher.in_queue_lock:
            if len(Batcher.in_queue) != 0:
                if count < len(Batcher.in_queue):
                    AriaLog.aria_log.debug("Removed records from the queue Records=" + str(count))
                    records = Batcher.in_queue[:count]
                    del Batcher.in_queue[:count]
                    return records
            return None
    
    @staticmethod        
    def remove_package_from_out():
        with Batcher.out_queue_lock:
            if len(Batcher.out_queue) > 0:
                package = Batcher.out_queue[0]
                del Batcher.out_queue[0]
                AriaLog.aria_log.debug("Remove package to be send")
                return package
            AriaLog.aria_log.debug("Sender thread was starved")
            return None
    
    @staticmethod
    def drop_events():
        # lock all objects and try to delete from the outer queue, then from the queue and then from the inner queue
    
        records_to_remove = aria.log_manager.LogManagerImpl.configuration.QUEUE_DROPPED_EVENTS
        AriaLog.aria_log.info("We are dropping events" + str(records_to_remove))
        records_removed = False
        
        #try:
        while records_to_remove != 0:
            with  Batcher.in_queue_lock:
                if len(Batcher.in_queue) >= records_to_remove:
                    records = Batcher.in_queue[:records_to_remove]
                    del Batcher.in_queue[:records_to_remove]
                    
                    for rec in records:
                        aria.log_manager.LogManagerImpl.subscribers.update(rec.tenant, [rec.sequence_id], SubscribeStatus.MAX_SIZE_REACHED)
                        aria.log_manager.LogManagerImpl.stats_manager.events_dropped(rec.tenant, 1)
                        aria.log_manager.LogManagerImpl.stats_manager.records_dropped_status(rec.tenant, 1, "queue_max_size_reached")
                    
                        if StatsConstants.stats_tenant_token != rec.tenant:
                            aria.log_manager.LogManagerImpl.decrement_events_in_memory(1)
                        
                    AriaLog.aria_log.info("Events are being dropped, dropped=" + str(len(records)))

                    # stats, subscribers, logManager, log
                    records_removed = True
                    
            if records_removed == False:
                with batch_package.BatchPackage.queue_lock:
                    index_found = -1
                    for index in range(len(batch_package.BatchPackage.queue)):
                        if len(batch_package.BatchPackage.queue[index].records_list) >= records_to_remove:
                            aria.log_manager.LogManagerImpl.subscribers.update(batch_package.BatchPackage.queue[index].tenant, batch_package.BatchPackage.queue[index].records_list, SubscribeStatus.MAX_SIZE_REACHED)
                            aria.log_manager.LogManagerImpl.stats_manager.events_dropped(batch_package.BatchPackage.queue[index].tenant, batch_package.BatchPackage.queue[index].records)
                            aria.log_manager.LogManagerImpl.stats_manager.records_dropped_status(batch_package.BatchPackage.queue[index].tenant, batch_package.BatchPackage.queue[index].records, "queue_max_size_reached")
                            if StatsConstants.stats_tenant_token != batch_package.BatchPackage.queue[index].tenant:
                                aria.log_manager.LogManagerImpl.decrement_events_in_memory(batch_package.BatchPackage.queue[index].records)
                            AriaLog.aria_log.info("Events are being dropped, dropped=" + str(batch_package.BatchPackage.queue[index].records))
                            index_found = index
                            records_removed = True
                            break
                        
                    if index_found != -1:
                        del batch_package.BatchPackage.queue[index_found]
            if records_removed == False:
                with Batcher.out_queue_lock:
                    index_found = -1
                    for index in range(len(Batcher.out_queue)):
                        if len(Batcher.out_queue[index].records_list) >= records_to_remove:
                            aria.log_manager.LogManagerImpl.subscribers.update(Batcher.out_queue[index].tenant, Batcher.out_queue[index].records_list, SubscribeStatus.MAX_SIZE_REACHED)
                            aria.log_manager.LogManagerImpl.stats_manager.events_dropped(Batcher.out_queue[index].tenant, Batcher.out_queue[index].records)
                            aria.log_manager.LogManagerImpl.stats_manager.records_dropped_status(Batcher.out_queue[index].tenant, Batcher.out_queue[index].records, "queue_max_size_reached")
                            if StatsConstants.stats_tenant_token != Batcher.out_queue[index].tenant:
                                aria.log_manager.LogManagerImpl.decrement_events_in_memory(Batcher.out_queue[index].records)
                            AriaLog.aria_log.info("Events are being dropped, dropped=" + str(Batcher.out_queue[index].records))
                            index_found = index
                            records_removed = True
                            break
                        
                    if index_found != -1:
                        del Batcher.out_queue[index_found]
                        
            if records_removed:
                records_to_remove = 0
            else:
                records_to_remove = int(records_to_remove/2)  # Worst case we can't find 200 events to remove, try to remove less events
        
        return records_removed
