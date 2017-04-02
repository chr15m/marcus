#!/usr/bin/env hy

(import
  [sys]
  [json]
  [sqlite3]
  [urllib2]
  [httplib]
  [socket]
  [hashlib [sha256]]
  [glob [glob]]
  [datetime [datetime timedelta]]
  [os [path makedirs]]
  [signal [signal SIGPIPE SIG_DFL]]
  [html2text [html2text]]
  [newspaper [Article]]
  [colorama]
  [whoosh.index [create_in open_dir]]
  [whoosh.fields [Schema ID TEXT DATETIME NUMERIC]]
  [whoosh.qparser [MultifieldParser]]
  [whoosh.qparser.dateparse [DateParserPlugin]]
  [url_analyzer [url_analyzer]])

(require [hy.contrib.loop [loop]])

; https://stackoverflow.com/questions/492483/setting-the-correct-encoding-when-piping-stdout-in-python
(reload sys)
(sys.setdefaultencoding "utf8")

; https://stackoverflow.com/a/16865106/2131094
(signal SIGPIPE SIG_DFL)

(colorama.init :autoreset True)

(def bookmarks-query-firefox "select moz_places.visit_count, moz_bookmarks.dateAdded, moz_places.url, moz_bookmarks.title from moz_places, moz_bookmarks where moz_places.id=moz_bookmarks.fk;")

(def whoosh-schema {"url_id" (ID :stored True :unique True)
                    "url" (TEXT :stored True :analyzer url_analyzer)
                    "title" (TEXT :stored True)
                    "content" (TEXT :stored True)
                    "content_markdown" (TEXT :stored True)
                    "date_added" (DATETIME :stored True)
                    "fail_count" (NUMERIC :stored True)
                    "fail_code" (TEXT :stored True)})

(def fail-count-limit 5)

(defn check-host [host]
  (loop [[times [1 5 10 15]] [status False]]
    (let [timeout (get times 0)
          result (or (and (try
                             (urllib2.urlopen host :timeout timeout)
                             (except [e Exception] None)) True)
                    status)
          remaining (cut times 1)]
      (if (and remaining (not result))
        (recur remaining result)
        (or result status)))))

(defn find-bookmarks []
  (+
   (glob (path.expanduser (path.join "~" ".mozilla" "firefox" "*.default" "places.sqlite")))
   (glob (path.expanduser "~/Library/Application Support/Firefox/Profiles/*.default/places.sqlite"))
   (glob (path.expanduser "~/Library/Mozilla/Firefox/Profiles/*.default/places.sqlite"))
   (glob (path.expanduser (path.join "~" ".config" "chromium" "Default" "Bookmarks")))
   (glob (path.expanduser "~/Library/Application Support/Google/Chrome/Default/Bookmarks"))))

(defn find-bookmark-files []
  (for [b (find-bookmarks)]
    (print b)))

(defn hash-url [url]
  (unicode (.hexdigest (sha256 url))))

; lol - int((datetime.datetime(1601, 1, 1) + datetime.timedelta(seconds=int(t) / 1000000)).strftime("%s")) * 1000000
; http://stackoverflow.com/a/19076132/2131094
(defn convert-chrome-time [t]
  (* (int (.strftime (+ (datetime 1601 1 1) (timedelta :seconds (/ (int t) 1000000))) "%s")) 1000000))

(defn load-bookmarks-chrome [bookmarks-json-file]
  (let [f (file bookmarks-json-file)
        raw-bookmarks (json.load f)]
    ; [visits date_added url title hash]
    (f.close)
    (sum
      (list-comp
        (list-comp [1
                    (convert-chrome-time (get c "date_added"))
                    (get c "url")
                    (get c "name")
                    (hash-url (get c "url"))]
                   [c (-> raw-bookmarks (get "roots") (get r) (get "children"))]
                   (= (get c "type") "url"))
        [r (get raw-bookmarks "roots")])
      [])))

(defn load-bookmarks-firefox [places-sqlite-file]
  ; load up the default places.sqlite
  (let [db (try (sqlite3.connect places-sqlite-file) (except [e Exception] (sys.exit "Could not find or open the places.sqlite file.")))
        c (db.cursor)]
    (list-comp
      (+ (list r) [(hash-url (get r 2))])
      [r (c.execute bookmarks-query-firefox)]
      (.startswith (get r 2) "http"))))

(defn load-bookmarks [bookmarks-file]
  (if (.endswith bookmarks-file ".sqlite")
    (load-bookmarks-firefox bookmarks-file)
    (load-bookmarks-chrome bookmarks-file)))

(defn create-whoosh-index [index-dir]
  (if (not (path.isdir index-dir))
    (makedirs index-dir))
  (create_in index-dir (apply Schema [] whoosh-schema)))

(defn load-whoosh-index []
  (let [index-dir (path.expanduser (path.join "~" ".marcus"))]
    (if (path.exists index-dir)
      (open_dir index-dir)
      (create-whoosh-index index-dir))))

(defn get-url [url]
  (try
    [None (.read (urllib2.urlopen url))]
    (except [e Exception] [(unicode e) None])))

(defn index-doc [index add-or-update doc]
  (let [writer (index.writer)]
    (apply (getattr writer (+ add-or-update "_document")) [] doc)
    (writer.commit)))

(defn index-bookmarks [args]
  (if (not (len args))
    (sys.exit "Bookmarks file not supplied.")
    ; check we can reach at least one known-good site
    (do
      (print "Start" (.strftime (.now datetime) "%Y-%m-%d %H:%M"))
      (if (not (or (check-host "http://google.com") (check-host "http://wikipedia.org")))
        (sys.exit "Bad internet connection.")
        (let [bookmarks-file (.join " " args)
              bookmarks (load-bookmarks bookmarks-file)
              index (load-whoosh-index)
              searcher (index.searcher)
              known-urls (dict-comp (get s "url_id") s [s (searcher.documents)])
              known-good-urls (list-comp u [[u v] (known-urls.items)] (or (not (.get v "fail_count" None)) (>= (.get v "fail_count" None) fail-count-limit)))
              bookmarks-count (len bookmarks)
              to-process-count (- (len (known-urls.keys)) (len known-good-urls))]
          (print "Bookmarks:" bookmarks-file)
          (when to-process-count
            (print (% "Indexing %d / %d bookmarks" (, to-process-count bookmarks-count))))
          (for [idx (range bookmarks-count)]
            (let [[visits date_added url title hash] (get bookmarks idx)
                  existing-doc (.get known-urls url {})]
              (let [fail-count (.get existing-doc "fail_count" None)]
                (if (and fail-count (< fail-count fail-count-limit))
                  (print "Retrying" url (% "(%d/ %d) times" (, fail-count (- fail-count-limit 1)))))
                (when (or
                        (not existing-doc)
                        (and fail-count (< fail-count fail-count-limit)))
                  (print (% "Indexing %s (%d / %d) %d%% done" (, url idx bookmarks-count (/ (* 100 idx) bookmarks-count))))
                  (let [a (Article url :fetch_images False)
                        datetime-added (datetime.fromtimestamp (/ date_added 1000000))]
                    (a.download)
                    (index-doc index (if existing-doc "update" "add")
                               (if a.html
                                 (do
                                   (a.parse)
                                   {"url_id" (unicode url) "url" (unicode url) "title" (unicode title) "content" (unicode a.text) "content_markdown" (unicode (html2text a.html)) "date_added" datetime-added "fail_count" None})
                                 (do
                                   (print "No content downloaded")
                                   {"url_id" (unicode url) "url" (unicode url) "fail_count" (if fail-count (inc fail-count) 1) "fail_code" "No content downloaded" "date_added" datetime-added}))))))))))))
  (print "Done" (.strftime (.now datetime) "%Y-%m-%d %H:%M")))

(defn perform-search [terms]
  (let [index (load-whoosh-index)
        searcher (index.searcher)
        query-parser (MultifieldParser ["url" "title" "content"] :schema index.schema)
        _ (.add_plugin query-parser (DateParserPlugin))
        query (query-parser.parse (.join " " (list terms)))
        results (searcher.search query :limit None)]
    (print "found" (len results))
    (print)
    (for [i (range (len results))]
      (let [r (get results i)
            url (.get r "url_id" "")
            title (.get r "title" "")
            date-added (.get r "date_added" "")
            fail-count (.get r "fail_count" None)
            fail-code (.get r "fail_code" None)
            content (.get r "content" None)
            index-number (+ (unicode (+ i 1)) ".")
            highlights (if content (.split (html2text (r.highlights "content")) "\n"))]
        (if fail-count
          ; failed result
          (do
            (print index-number (+ "\t" url))
            (print (+ "\t" fail-code)))
          ; regular result
          (do
            (if (and title (not (= title url)))
              (do
                (print index-number (+ "\t" colorama.Fore.BLUE colorama.Style.BRIGHT colorama.Style.BRIGHT title))
                (print (+ "\t" colorama.Fore.GREEN url)))
              (print index-number (+ "\t" title)))
            (print "\tAdded:" (.strftime date-added "%Y-%m-%d"))
            (when highlights
              (for [h highlights]
                (if h
                  (print (+ "\t> ..."  colorama.Style.BRIGHT h colorama.Style.RESET_ALL "..."))))))))
      (print))))

(defn usage [argv]
  (let [bin (path.basename (get argv 0))]
    (print "Usages:")
    (print "\t" bin "--index BOOKMARK-FILE")
    (print "\t" bin "--find-bookmark-files")
    (print "\t" bin "SEARCH TERMS ...")
    (print)
    (print "Bookmark files can be in Firefox or Chromium format.")
    (print)
    (print "For details on search terms see:")
    (print "\thttps://whoosh.readthedocs.io/en/latest/querylang.html")
    (print)
    (print "Available search fields:")
    (print "\t" (.join " " (list-comp (.replace (name k) "-" "_") [k (whoosh-schema.keys)])))))

(defn main [argv]
  (try
    (cond
      [(in "--index" sys.argv) (index-bookmarks (cut argv 2))]
      [(in "--find-bookmark-files" sys.argv) (find-bookmark-files)]
      [(> (len argv) 1) (perform-search (cut argv 1))]
      [True (usage sys.argv)])
    (except [e KeyboardInterrupt]
      (print "Exiting."))))

(if (= __name__ "__main__")
  (main sys.argv))

