import re
import urlparse

from whoosh.analysis import LowercaseFilter, StopFilter, Token, Tokenizer

query_re = re.compile('[ +&=]')

class UrlTokenizer(Tokenizer):
	def __call__(self, value, start_pos=0, start_char=0, positions=False, **kwargs):
		parts = urlparse.urlparse(value)

		#t = Token(text=parts.scheme, boost=0.5)
		#if positions:
		#	t.pos = start_pos + 1
		#yield t

		hostport = parts.netloc.split(':')
		hostparts = hostport.pop(0).split(".");

		#print hostparts
		for p in hostparts:
			t = Token(text=p, boost=1.0)
			if positions:
				t.pos = start_pos + 1
			yield t

		for x in range(len(hostparts) - 1):
                        p = ".".join(hostparts[x:])
			t = Token(text=p, boost=1.0)
			if positions:
				t.pos = start_pos + 1
			yield t
         
		for p in [x for x in parts.path.split('/') if x]:
			t = Token(text=p, boost=1.0)
			if positions:
				t.pos = start_pos + 1
			yield t

		for p in [x for x in parts.fragment.split(' ') if x]:
			t = Token(text=p, boost=1.0)
			if positions:
				t.pos = start_pos + 1
			yield t

		for p in [x for x in query_re.split(parts.query) if x]:
			t = Token(text=p, boost=1.0)
			if positions:
				t.pos = start_pos + 1
			yield t

		for p in [x for x in parts.fragment.split(' ') if x]:
			t = Token(text=p, boost=1.0)
			if positions:
				t.pos = start_pos + 1
			yield t

url_analyzer = UrlTokenizer() | LowercaseFilter() | StopFilter()
