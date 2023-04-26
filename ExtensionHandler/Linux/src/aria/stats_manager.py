from __future__ import absolute_import
import datetime 
import sys
import time
import uuid
import threading
from .event_properties import EventProperties
from .log_config import AriaLog
import aria.log_manager

class StatsConstants(object):
    SDK_VERSION      = "AST_Python_Linux_no_1.3.9.0"
    RECORDS_SENT     = "records_sent_count"
    RECORDS_DROPPED  = "records_dropped_count"
    RECORDS_RECEIVED = "records_received_count"
    RECORDS_TRIED = "records_tried_to_send_count"
    REJECTED_COUNT = "r_count"
    RECORDS_IN_MEMORY = "infl" 
    RECORDS_IN_QUEUE = "inq"
    RECORDS_RETRY = "retry"
    RECORDS_DROPPED_SERVER_DECLINED = "h_"
    RETRY_HTTP = "rt_h_"
    AVERAGE_PACKAGE_SIZE = "aps"
    TOTAL_DATA_SEND = "tds"
    AVERAGE_RECORD_SIZE = "ars"
    DROP_BOND_FAIL = "d_bond_fail"
    FLUSH_AND_TEAR_DOWN = "ats" # act_teardown_stats

    STATS_CADENCE = 1 * 60
    event_name = "act_stats"
    stats_tenant_token = "cdb783887a694494bab466421a591fa3-f8a13b4b-18f4-40fe-976c-c78a3cdb9b8f-7520"
    tenant_id = "TenantId"
    tenant = "AST"
    ast_platform = ""
    language = "Python"
    version = "1.3.9.0"
    python_version = "2"
    if sys.version_info[0] >= 3:
        python_version = "3"

    is_wrapper = "no"
    
    def PopulateSDKVersion(self):
        import platform
        StatsConstants.ast_platform = platform.system()
        StatsConstants.SDK_VERSION = StatsConstants.tenant + "_" + \
                                     StatsConstants.ast_platform + "_" + \
                                     StatsConstants.language + "_" + \
                                     StatsConstants.python_version + "_" + \
                                     StatsConstants.is_wrapper + "_" + \
                                     StatsConstants.version

        AriaLog.aria_log.debug("platform=" + StatsConstants.ast_platform)
    
class StatsManager(object):
    def __init__(self):
        self.daemon_running = True
        self.events_dropped_lock =  threading.RLock()
        self.events_send_lock = threading.RLock()
        self.events_received_lock = threading.RLock()
        self.events_tried_lock = threading.RLock()
        self.stats = {}
        self.stats_count = {}
        self.__init_worker_thread()
        self.flushed = False
        StatsConstants.cadence = aria.log_manager.LogManagerImpl.configuration.STATS_CADENCE

    def __init_worker_thread(self):
        self.worker_thread = threading.Thread(target = self.__run)
        self.worker_thread.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON 
        self.worker_thread.start()
    
    def __hasStats(self, stat):
        has_stat = 0
        has_stat += stat[StatsConstants.RECORDS_SENT] if StatsConstants.RECORDS_SENT in stat else 0
        has_stat += stat[StatsConstants.RECORDS_DROPPED] if StatsConstants.RECORDS_DROPPED in stat else 0
        has_stat += stat[StatsConstants.RECORDS_RECEIVED] if StatsConstants.RECORDS_RECEIVED in stat else 0
        has_stat += stat[StatsConstants.RECORDS_TRIED] if StatsConstants.RECORDS_TRIED in stat else 0
        
        return has_stat != 0

    def flush(self):
        AriaLog.aria_log.info("Flush was called for stats manager")
        self.flushed = True
        self.daemon_running = False
        self.worker_thread.join(3)
        del self.worker_thread
        stats_copy = dict(self.stats)
        self.__sentStats(stats_copy)
        del self.stats
        del self

    def __sentStats(self, stats):
        from aria.log_manager import LogManagerImpl
        
        for stat in stats:
            if self.__hasStats(self.stats[stat]) and stat != StatsConstants.stats_tenant_token:
                
                # Creating the tenantID
                tenant_id_finish_index = stat.index('-')
                if tenant_id_finish_index == -1:
                    continue
                tenant_id = stat[0:tenant_id_finish_index]
                
                event = EventProperties(StatsConstants.event_name)
                event.set_property("sdk-version", StatsConstants.SDK_VERSION)
                event.set_property("S_t", StatsConstants.tenant)
                event.set_property("S_p", StatsConstants.ast_platform)
                event.set_property("S_k", StatsConstants.language)
                event.set_property("S_j", "no")
                event.set_property("S_v", StatsConstants.version)
                event.set_property(StatsConstants.tenant_id, tenant_id)
                
                # Adding the stats
                with self.events_send_lock and self.events_received_lock and self.events_dropped_lock and self.events_tried_lock:
                    for sub_stat in self.stats[stat]:
                        if (stat in self.stats_count) and (sub_stat in self.stats_count[stat]):
                            if self.stats_count[stat][sub_stat] != 0 and self.stats[stat][sub_stat] / self.stats_count[stat][sub_stat] != 0:
                                event.set_property(sub_stat, str(self.stats[stat][sub_stat] / self.stats_count[stat][sub_stat]))
                                AriaLog.aria_log.debug(sub_stat + "=" + str(self.stats[stat][sub_stat] / self.stats_count[stat][sub_stat]) + ", Tenant Token=" + stat)
                                self.stats_count[stat][sub_stat] = 0
                        elif self.stats[stat][sub_stat] != 0:
                            event.set_property(sub_stat, str(self.stats[stat][sub_stat]))
                            AriaLog.aria_log.debug(sub_stat +"=" + str(self.stats[stat][sub_stat]) + ", Tenant Token=" + stat)
                        self.stats[stat][sub_stat] = 0
                try:
                    LogManagerImpl.get_logger("", StatsConstants.stats_tenant_token).log_event(event)
                except:
                    pass       
                 
    def __run(self):
        while self.daemon_running:
            stats_copy = dict(self.stats)
            self.__sentStats(stats_copy)
            # For a faster stop for flush
            for index in range(StatsConstants.STATS_CADENCE):
                if self.daemon_running and self.daemon_running:
                    time.sleep(1)
                else:
                    return
            AriaLog.aria_log.info("__run daemon_running end for stats manager")
            if aria.log_manager.LogManagerImpl.flushed_called == True:
                self.daemon_running = False
                return
                
    def __get_Stats(self, tenant_token):
        if tenant_token not in self.stats:
            self.stats[tenant_token] = {}
        return self.stats[tenant_token]

    def events_send(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_send_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_SENT not in token_stats:
                token_stats[StatsConstants.RECORDS_SENT] = 0
            token_stats[StatsConstants.RECORDS_SENT] += count

    def events_dropped(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_dropped_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_DROPPED not in token_stats:
                token_stats[StatsConstants.RECORDS_DROPPED] = 0
            token_stats[StatsConstants.RECORDS_DROPPED] += count
        
    def events_received(self, tenant_token, count = 1):
        if self.flushed == True:
            return
        with self.events_received_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_RECEIVED not in token_stats:
                token_stats[StatsConstants.RECORDS_RECEIVED] = 0
            token_stats[StatsConstants.RECORDS_RECEIVED] += 1

    def events_tried(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_TRIED not in token_stats:
                token_stats[StatsConstants.RECORDS_TRIED] = 0
            token_stats[StatsConstants.RECORDS_TRIED] += count
    
    def rejected_count(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.REJECTED_COUNT not in token_stats:
                token_stats[StatsConstants.REJECTED_COUNT] = 0
            token_stats[StatsConstants.REJECTED_COUNT] += count

    # TODO
    def records_in_memory(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_IN_MEMORY not in token_stats:
                token_stats[StatsConstants.RECORDS_IN_MEMORY] = 0
            token_stats[StatsConstants.RECORDS_IN_MEMORY] += count
    
    # TODO
    def records_in_queue(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_IN_QUEUE not in token_stats:
                token_stats[StatsConstants.RECORDS_IN_QUEUE] = 0
            token_stats[StatsConstants.RECORDS_IN_QUEUE] += count
    
    def records_retry(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.RECORDS_RETRY not in token_stats:
                token_stats[StatsConstants.RECORDS_RETRY] = 0
            token_stats[StatsConstants.RECORDS_RETRY] += count

    def records_dropped_status(self, tenant_token, count, status):
        records_dropped_server = StatsConstants.RECORDS_DROPPED_SERVER_DECLINED + str(status)
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if records_dropped_server not in token_stats:
                token_stats[records_dropped_server] = 0
            token_stats[records_dropped_server] += count
            
    def records_retry_status(self, tenant_token, count, status):
        records_retry_server = StatsConstants.RETRY_HTTP + str(status)
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if records_retry_server not in token_stats:
                token_stats[records_retry_server] = 0
            token_stats[records_retry_server] += count
            
    def average_record_size(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            if tenant_token not in self.stats_count:
                self.stats_count[tenant_token] = {}
            if StatsConstants.AVERAGE_RECORD_SIZE not in  self.stats_count[tenant_token]:
                self.stats_count[tenant_token][StatsConstants.AVERAGE_RECORD_SIZE] = 0
            self.stats_count[tenant_token][StatsConstants.AVERAGE_RECORD_SIZE] += 1
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.AVERAGE_RECORD_SIZE not in token_stats:
                token_stats[StatsConstants.AVERAGE_RECORD_SIZE] = 0
            token_stats[StatsConstants.AVERAGE_RECORD_SIZE] += count
            
    def average_package_size(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            if tenant_token not in self.stats_count:
                self.stats_count[tenant_token] = {}
            if StatsConstants.AVERAGE_PACKAGE_SIZE not in  self.stats_count[tenant_token]:
                self.stats_count[tenant_token][StatsConstants.AVERAGE_PACKAGE_SIZE] = 0
            self.stats_count[tenant_token][StatsConstants.AVERAGE_PACKAGE_SIZE] += 1
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.AVERAGE_PACKAGE_SIZE not in token_stats:
                token_stats[StatsConstants.AVERAGE_PACKAGE_SIZE] = 0
            token_stats[StatsConstants.AVERAGE_PACKAGE_SIZE] += count
    
    def records_bond_failed(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.DROP_BOND_FAIL not in token_stats:
                token_stats[StatsConstants.DROP_BOND_FAIL] = 0
            token_stats[StatsConstants.DROP_BOND_FAIL] += count
    
    def total_data_send(self, tenant_token, count):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            token_stats = self.__get_Stats(tenant_token)
            if StatsConstants.TOTAL_DATA_SEND not in token_stats:
                token_stats[StatsConstants.TOTAL_DATA_SEND] = 0
            token_stats[StatsConstants.TOTAL_DATA_SEND] += count

    def flush_and_tead_down(self):
        if self.flushed == True:
            return
        with self.events_tried_lock:
            for k, v  in self.stats.items():
                self.stats[k][StatsConstants.FLUSH_AND_TEAR_DOWN] = 1