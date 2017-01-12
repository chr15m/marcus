import urlparse

from whoosh.analysis import LowercaseFilter, StopFilter, Token, Tokenizer, StandardAnalyzer

class UrlTokenizer(Tokenizer):
    def __call__(self, value, start_pos=0, start_char=0, positions=False, **kwargs):
        ana = StandardAnalyzer()
        parts = urlparse.urlparse(value)

        #t = Token(text=parts.scheme, boost=0.5)
        #if positions:
        #    t.pos = start_pos + 1
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
         
        if parts.path:
            for p in [x.text for x in ana(parts.path) if x.text]:
                t = Token(text=p, boost=1.0)
                if positions:
                    t.pos = start_pos + 1
                yield t

        if parts.fragment:
            for p in [x.text for x in ana(parts.fragment) if x.text]:
                t = Token(text=p, boost=1.0)
                if positions:
                    t.pos = start_pos + 1
                yield t

        if parts.query:
            for p in [x.text for x in ana(parts.query) if x.text]:
                t = Token(text=p, boost=1.0)
                if positions:
                    t.pos = start_pos + 1
                yield t

url_analyzer = UrlTokenizer() | LowercaseFilter() | StopFilter()
