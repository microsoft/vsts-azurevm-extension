from __future__ import absolute_import
import sys

class CompactBinaryProtocolWriter(object):
	write_file_map = {}
	write_var_uint_map = {}
	write_var_int_map = {}
	write_var_int_map_limit = 2000
	initialized = False
	
	def __init__(self):
		self._output = []
		self._output_string_size = 0
		
	@staticmethod
	def InitGenerated():
		if CompactBinaryProtocolWriter.initialized == False:
			CompactBinaryProtocolWriter.WriteFiledBeginGenerate()
			CompactBinaryProtocolWriter.WriteVarUIntGenerate()
			CompactBinaryProtocolWriter.WriteVarIntGenerate()
			CompactBinaryProtocolWriter.initialized = True
			
	@staticmethod
	def WriteFiledBeginGenerate():
		for field_type in range(0,256):
			for field_id in range(0,40):
				result = []
				if field_id <= 5:
					result.append(field_type | (field_id << 5))
				elif field_id <= 0xff:
					result.append(field_type | (6 << 5));
					result.append(field_id & 255)
				else:
					result.append(field_type | ( 7 << 5 ))
					result.append(field_id & 255)
					result.append(field_id >> 8)
					
				CompactBinaryProtocolWriter.write_file_map[(field_type, field_id)] = result
	
	@staticmethod
	def WriteVarIntGenerate():
		for i in range(CompactBinaryProtocolWriter.write_var_int_map_limit):
			value = i
			result = []
			value = (value << 1) ^ (value >> 31)
			while value > 127:
				result.append((value & 127) | 128);
				value = value >> 7
			result.append(value & 127)
			CompactBinaryProtocolWriter.write_var_int_map[i] = result
	
	@staticmethod
	def WriteVarUIntGenerate():
		for i in range(CompactBinaryProtocolWriter.write_var_int_map_limit):
			value = i
			result = []
			while value > 127:
				result.append((value & 127) | 128);
				value = value >> 7
			result.append(value & 127)
			CompactBinaryProtocolWriter.write_var_uint_map[i] = result
	
	def WriteFieldBegin(self, field_type, field_id, metadata = None):
		self._output += CompactBinaryProtocolWriter.write_file_map[(field_type, field_id)]
	
	
	def WriteVarInt(self, value):
		while value > 127:
			self._output.append((value & 127) | 128);
			value = value >> 7
		self._output.append(value & 127)
	
	def WriteInt32(self, value):
		if value < CompactBinaryProtocolWriter.write_var_int_map_limit:
			self._output += CompactBinaryProtocolWriter.write_var_int_map[value]
		else:
			value = (value << 1) ^ (value >> 31)
			while value > 127:
				self._output.append((value & 127) | 128);
				value = value >> 7
			self._output.append(value & 127)
	
	def WriteUInt32(self, value):
		if value < CompactBinaryProtocolWriter.write_var_int_map_limit:
			self._output += CompactBinaryProtocolWriter.write_var_uint_map[value]	
		else:
			while value > 127:
				self._output.append((value & 127) | 128);
				value = value >> 7
			self._output.append(value & 127)
	
	def WriteString(self, string):
		if sys.version_info[0] < 3:
			if type(string) == unicode:
				string = string.encode('utf8')
			
		if string == "":
			self.WriteUInt32(0)
		else:
			self.WriteUInt32(len(string))
			self._output.append(string)
			self._output_string_size += len(string)
	
	def WriteContainerBegin(self, size, element_type):
		self._output.append(element_type)
		self.WriteUInt32(size)
	
	def WriteMapContainerBegin(self, size, key_type, value_type):
		self._output.append(key_type)
		self._output.append(value_type)
		self.WriteUInt32(size)
	
	def WriteStructEnd(self, is_base):
		self._output.append(1 if is_base == True else 0)
	
	def WriteUInt64(self, value):
		self.WriteVarInt(value)
	
	def WriteInt64(self, value):
		self.WriteUInt64((value << 1) ^ (value >> 63))
	
	def WriteBlob(self, value):
		self._output.append(1 if value == True else 0 )
	