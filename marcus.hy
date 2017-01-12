#!/usr/bin/env hy

(import
  [sys]
  [sqlite3]
  [urllib2]
  [httplib]
  [socket]
  [hashlib [sha256]]
  [glob [glob]]
  [datetime [datetime]]
  [os [path makedirs]]
  [html2text [html2text]]
  [newspaper [Article]]
  [colorama]
  [whoosh.index [create_in open_dir]]
  [whoosh.fields [Schema ID TEXT DATETIME NUMERIC]]
  [whoosh.qparser [MultifieldParser]]
  [whoosh.qparser.dateparse [DateParserPlugin]]
  [url_analyzer [url_analyzer]])

(require hy.contrib.loop)

; https://stackoverflow.com/questions/492483/setting-the-correct-encoding-when-piping-stdout-in-python
(reload sys)
(sys.setdefaultencoding "utf8")

(colorama.init :autoreset true)

(def bookmarks-query "select moz_places.visit_count, moz_bookmarks.dateAdded, moz_places.url, moz_bookmarks.title from moz_places, moz_bookmarks where moz_places.id=moz_bookmarks.fk;")

(def whoosh-schema {"url_id" (ID :stored true :unique true)
                    "url" (TEXT :stored true :analyzer url_analyzer)
                    "title" (TEXT :stored true)
                    "content" (TEXT :stored true)
                    "content_markdown" (TEXT :stored true)
                    "date_added" (DATETIME :stored true)
                    "fail_count" (NUMERIC :stored true)
                    "fail_code" (TEXT :stored true)})

(def fail-count-limit 5)

(defn check-host [host]
  (loop [[times [1 5 10 15]] [status false]]    
    (let [[timeout (get times 0)]
          [result (or (and (try
                             (urllib2.urlopen host :timeout timeout)
                             (catch [e Exception] None)) true)
                    status)]
          [remaining (slice times 1)]]
      (if (and remaining (not result))
        (recur remaining result)
        (or result status)))))

(defn load-bookmarks []
  ; load up the default places.sqlite
  (let [[places-sqlite (glob (path.expanduser (path.join "~" ".mozilla" "firefox" "*.default" "places.sqlite")))]
        [db (try (sqlite3.connect (get places-sqlite 0)) (catch [e Exception] (sys.exit "Could not find or open the places.sqlite file.")))]
        [c (db.cursor)]]
    (list-comp
      (+ (list r) [(unicode (.hexdigest (sha256 (get r 2))))])
      [r (c.execute bookmarks-query)]
      (.startswith (get r 2) "http"))))

(defn create-whoosh-index [index-dir]
  (if (not (path.isdir index-dir))
    (makedirs index-dir))
  (create_in index-dir (apply Schema [] whoosh-schema)))

(defn load-whoosh-index []
  (let [[index-dir (path.expanduser (path.join "~" ".marcus"))]]
    (if (path.exists index-dir)
      (open_dir index-dir)
      (create-whoosh-index index-dir))))

(defn get-url [url]
  (try
    [None (.read (urllib2.urlopen url))]
    (catch [e Exception] [(unicode e) None])))

(defn index-doc [index add-or-update doc]
  (let [[writer (index.writer)]]
    (apply (getattr writer (+ add-or-update "_document")) [] doc)
    (writer.commit)))

(defn index-bookmarks []
  ; check we can reach at least one known-good site
  (print "Start" (.strftime (.now datetime) "%Y-%m-%d %H:%M"))
  (if (not (or (check-host "http://google.com") (check-host "http://wikipedia.org")))
    (sys.exit "Bad internet connection.")
    (let [[bookmarks (load-bookmarks)]
          [index (load-whoosh-index)]
          [searcher (index.searcher)]
          [known-urls (dict-comp (get s "url_id") s [s (searcher.documents)])]
          [bookmarks-count (len bookmarks)]]
      (print (% "Indexing %d / %d bookmarks" (, (- (len bookmarks) (len (.keys known-urls))) (len bookmarks))))
      (for [idx (range (len bookmarks))]
        (let [[[visits date_added url title hash] (get bookmarks idx)]
              [existing-doc (.get known-urls url {})]]
          ;(print w)
          ;(print index.schema)
          ;(print url (in url known-urls))
          (let [[fail-count (.get existing-doc "fail_count" nil)]]
            (if (and fail-count (< fail-count fail-count-limit))
              ;(print (% "fail count for %s is %d" (, url fail-count)))
              (print "Retrying" url))
            (when (or
                    (not existing-doc)
                    (and fail-count (< fail-count fail-count-limit)))
              (print (% "Indexing %s (%d / %d) %d%% done" (, url idx bookmarks-count (/ (* 100 idx) bookmarks-count))))
              (let [[a (Article url :fetch_images false)]
                    [datetime-added (datetime.fromtimestamp (/ date_added 1000000))]]
                (a.download)
                (index-doc index (if existing-doc "update" "add")
                           (if a.html
                             (do
                               (a.parse)
                               {"url_id" (unicode url) "url" (unicode url) "title" (unicode title) "content" (unicode a.text) "content_markdown" (unicode (html2text a.html)) "date_added" datetime-added "fail_count" nil})
                             (do
                               (print "No content downloaded")
                               {"url_id" (unicode url) "url" (unicode url) "fail_count" (if fail-count (inc fail-count) 1) "fail_code" "No content downloaded" "date_added" datetime-added})))))))))))

(defn perform-search [terms]
  (let [[index (load-whoosh-index)]
        [searcher (index.searcher)]
        [query-parser (MultifieldParser ["url" "title" "content"] :schema index.schema)]
        [_ (.add_plugin query-parser (DateParserPlugin))]
        [query (query-parser.parse (.join " " terms))]
        [results (searcher.search query :limit None)]]
    ;(print "Query:" (.join " " terms))
    (print "found" (len results))
    (print)
    (for [i (range (len results))]
      (let [[r (get results i)]
            [url (.get r "url_id" "")]
            [title (.get r "title" "")]
            [date-added (.get r "date_added" "")]
            [fail-count (.get r "fail_count" None)]
            [fail-code (.get r "fail_code" None)]
            [content (.get r "content" None)]
            [index-number (+ (unicode (+ i 1)) ".")]
            [highlights (if content (.split (html2text (r.highlights "content")) "\n"))]]
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
  (let [[bin (get argv 0)]]
    (print "Usages:")
    (print "\t" bin "--index")
    (print "\t" bin "SEARCH TERMS ...")
    (print)
    (print "For details on search terms see:")
    (print "\thttps://whoosh.readthedocs.io/en/latest/querylang.html")
    (print "Available search fields:")
    (print "\t" (.join " " (list-comp (.replace (name k) "-" "_") [k (whoosh-schema.keys)])))))

(if (= __name__ "__main__")
  (try
    (cond
      [(in "--index" sys.argv) (index-bookmarks)]
      [(> (len sys.argv) 1) (perform-search (slice sys.argv 1))]
      [True (usage sys.argv)])
    (catch [e KeyboardInterrupt]
      (print "Exiting."))))

