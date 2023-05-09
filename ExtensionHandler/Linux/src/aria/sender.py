from __future__ import absolute_import
from . import six
#from six.moves.http_client import HTTPSConnection
from aria.six.moves.http_client import HTTPSConnection
import ssl
import aria.log_manager
from threading import Thread
from time import sleep
from . import batcher
from . import utilities
from threading import RLock
import datetime
from multiprocessing import Pool
from .stats_manager import StatsConstants
from random import randint
from _random import Random
from random import random
from .log_config import AriaLog
from sys import exc_info
from .subscribe import SubscribeStatus
import socket
from aria.six.moves import range

class AriaSender(object):
    def __init__(self, sender_index):
        AriaLog.aria_log.info("AriaSender was initialized")
        try:
            self.sender_index = sender_index
            self.pipeline_url = "pipe.skype.com"
            self.connection = HTTPSConnection(self.pipeline_url, timeout = 10)
            
            if hasattr(ssl, '_create_unverified_context'):
                ssl._create_default_https_context = ssl._create_unverified_context
                
            self.run_thread_running = False
            self.check_thread_running = False
            self.run_thread = Thread(target = self.__run)
            self.run_thread.daemon = aria.log_manager.LogManagerImpl.configuration.ALL_THREADS_DEAMON
            self.package_to_send = None
            self.package_retry = 0  # TODO implement retry logic
            self.package_size = 0
            self.retry_count = aria.log_manager.LogManagerImpl.configuration.MAX_RETRY_COUNT
            self.retry_seconds = [0,1]
            for val in range(self.retry_count):
                self.retry_seconds.append(self.retry_seconds[val + 1] * 2)
                
            self.initialiezed = True
        except:
            self.initialiezed = False
            AriaLog.aria_log.warning("AriaSender failed to initialize" + str(exc_info()[0]))
        
    def start_thread(self):
        AriaLog.aria_log.info("AriaSender " + "Sender" + str(self.sender_index) + " thread started")
        if self.initialiezed == False:
            return
        self.run_thread_running = True
        self.run_thread.start()
            
    def stop_thread(self):
        if self.initialiezed == False:
            return
        
        AriaLog.aria_log.info("AriaSender " + "Sender" + str(self.sender_index) + " thread stopped")
        
        self.run_thread_running = False 
        self.run_thread.join()
        
    def __run(self):
        if self.initialiezed == False:
            return
        
        while self.run_thread_running == True:
            try:
                self.package_to_send = batcher.Batcher.remove_package_from_out()
                if self.package_to_send != None:
                    
                    response = self.send_to_pipeline()
                    
                    if StatsConstants.stats_tenant_token != self.package_to_send.tenant: 
                        aria.log_manager.LogManagerImpl.decrement_events_in_memory(self.package_to_send.records)
                    
                    if response == None: 
                        aria.log_manager.LogManagerImpl.subscribers.update(self.package_to_send.tenant, self.package_to_send.records_list, SubscribeStatus.NO_INTERNET_CONNECTION)
                        if aria.log_manager.LogManagerImpl.stats_manager != None:                        
                            aria.log_manager.LogManagerImpl.stats_manager.events_dropped(self.package_to_send.tenant, self.package_to_send.records)
                            aria.log_manager.LogManagerImpl.stats_manager.average_package_size(self.package_to_send.tenant, len(self.package_to_send.serialized))
                            aria.log_manager.LogManagerImpl.stats_manager.average_record_size(self.package_to_send.tenant, len(self.package_to_send.serialized)/self.package_to_send.records)
                        continue
                    # Alert all the subscribers  
                    aria.log_manager.LogManagerImpl.subscribers.update(self.package_to_send.tenant, self.package_to_send.records_list, response.status)
                        
                    if response.status == 200:
                        if aria.log_manager.LogManagerImpl.stats_manager != None:
                            aria.log_manager.LogManagerImpl.stats_manager.events_send(self.package_to_send.tenant, self.package_to_send.records)
                            aria.log_manager.LogManagerImpl.stats_manager.total_data_send(self.package_to_send.tenant, len(self.package_to_send.serialized))
                    else:
                        if aria.log_manager.LogManagerImpl.stats_manager != None:
                            aria.log_manager.LogManagerImpl.stats_manager.events_dropped(self.package_to_send.tenant, self.package_to_send.records)
                            aria.log_manager.LogManagerImpl.stats_manager.records_dropped_status(self.package_to_send.tenant, self.package_to_send.records, response.status)
                    
                    if aria.log_manager.LogManagerImpl.stats_manager != None:                    
                        aria.log_manager.LogManagerImpl.stats_manager.average_package_size(self.package_to_send.tenant, len(self.package_to_send.serialized))
                        aria.log_manager.LogManagerImpl.stats_manager.average_record_size(self.package_to_send.tenant, len(self.package_to_send.serialized)/self.package_to_send.records)
                    
                    AriaLog.aria_log.debug("Sender" + str(self.sender_index) + " Package=1, Size=" + str(len(self.package_to_send.serialized)) + " Response=" + str(response.status) + " Records=" + str(self.package_to_send.records)) 
                else:
                    sleep(aria.log_manager.LogManagerImpl.configuration.ARIA_SENDER_TIMER)
            except:
                AriaLog.aria_log.warning("AriaSender has failed" + str(exc_info()[0]))
                sleep(aria.log_manager.LogManagerImpl.configuration.ARIA_SENDER_TIMER)
            if aria.log_manager.LogManagerImpl.flushed_called == True:
                AriaLog.aria_log.info("Sender aria.LogManagerImpl.flushed_called")
                self.run_thread_running = False
                return

    def send_to_pipeline(self):
        send_tries = 0
        close_connection = False
        response = None
        try:
            while send_tries < self.retry_count:
                retry_cause_found = False
                if close_connection == True:
                    close_connection = False
                    self.connection.close()
                    self.connection = HTTPSConnection(self.pipeline_url, timeout=10)
                    AriaLog.aria_log.info("We had to start a new connection, old one was unusable")

                try:
                    if aria.log_manager.LogManagerImpl.configuration.SUPPORT_GZIP == True:
                        out_buffer = utilities.AriaUtilities.gzip_compress(self.package_to_send.serialized)
                    else:
                        out_buffer = self.package_to_send_serialize
                    aria.log_manager.LogManagerImpl.stats_manager.events_tried(self.package_to_send.tenant, self.package_to_send.records)
                    
                    headers = \
                    {
                        "Content-Type": "application/bond-compact-binary",
                        "Client-Id": "NO_AUTH",
                        "Connection":" keep-alive",
                        "Expect": "100-continue",
                        "Content-Length": str(len(out_buffer)),
                        "x-apikey": self.package_to_send.tenant,
                        "Sdk-version": StatsConstants.SDK_VERSION,
                    }
                    
                    if aria.log_manager.LogManagerImpl.configuration.SUPPORT_GZIP == True:
                        headers["Content-Encoding"] = "gzip"
                
                    try:
                        self.connection.request('POST', 'https://' + self.pipeline_url + '/Collector/3.0/', out_buffer, headers)
                    except:
                        close_connection = True
                        AriaLog.aria_log.info("Sender" + str(self.sender_index) + "Trying to send an event failed " + str(exc_info()[0]))
                        aria.log_manager.LogManagerImpl.stats_manager.records_retry_status(self.package_to_send.tenant, self.package_to_send.records, AriaSender.create_event_name(str(exc_info()[0])))
                        retry_cause_found = True
                    finally:                
                        try:
                            response = self.connection.getresponse()
                            response.read()
                        except:
                            response_error = AriaSender.create_event_name(str(exc_info()[0]))
                            response = None    # We have to do this in order to reuse the connection. otherwise it will refuse all further connections 
                        
                    if response != None and response.status == 200:
                        return response 
                    else:
                        if response != None:
                            AriaLog.aria_log.debug("Sender" + str(self.sender_index) + "Retry because of status code " + str(response.status))
                            aria.log_manager.LogManagerImpl.stats_manager.records_retry_status(self.package_to_send.tenant, self.package_to_send.records, response.status)
                        elif retry_cause_found == False:
                            aria.log_manager.LogManagerImpl.stats_manager.records_retry_status(self.package_to_send.tenant, self.package_to_send.records, response_error)
                            
                        aria.log_manager.LogManagerImpl.stats_manager.records_retry(self.package_to_send.tenant, self.package_to_send.records)
                        send_tries += 1
                        if send_tries < self.retry_count:
                            sleep(self.retry_seconds[send_tries] * (0.8 + random() * 0.4))
                except:
                        AriaLog.aria_log.warning("Sender" + str(self.sender_index) + "Retry because of Error=" + str(exc_info()[0]))
                        if aria.log_manager.LogManagerImpl.stats_manager != None:
                            aria.log_manager.LogManagerImpl.stats_manager.records_retry(self.package_to_send.tenant, self.package_to_send.records)
                            aria.log_manager.LogManagerImpl.stats_manager.records_retry_status(self.package_to_send.tenant, self.package_to_send.records, AriaSender.create_event_name(str(exc_info()[0])))
                        send_tries += 1
                        if send_tries < self.retry_count:
                            sleep(self.retry_seconds[send_tries] * (0.8 + random() * 0.4))
                            
        except BaseException as e:
            close_connection = True
            AriaLog.aria_log.warning("Sender" + str(self.sender_index) + "Trying to send an event failed " + str(exc_info()[0]) + " message=" + str(e))
        
        if close_connection == True:
            self.connection.close()
            self.connection = HTTPSConnection(self.pipeline_url, timeout=10)
            AriaLog.aria_log.info("We had to start a new connection, old one was unusable")
            
        return response
    
    @staticmethod
    def create_event_name(string):
        
        try:
            poz1 = string.find("\'")
            poz2 = string[poz1 + 1:].find("\'")
            string = string[poz1 + 1:poz1 + poz2 + 1]
            string = string.replace(".", "_")
            return string   
        except:
            return "request_error"