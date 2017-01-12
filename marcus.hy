#!/usr/bin/env hy

(import
  [sys]
  [sqlite3]
  [urllib2]
  [httplib]
  [hashlib [sha256]]
  [glob [glob]]
  [datetime [datetime]]
  [os [path makedirs]]
  [html2text [html2text]]
  [whoosh.index [create_in open_dir]]
  [whoosh.fields [Schema ID TEXT DATETIME NUMERIC]])

; https://stackoverflow.com/questions/492483/setting-the-correct-encoding-when-piping-stdout-in-python
(reload sys)
(sys.setdefaultencoding "utf8")

(def bookmarks-query "select moz_places.visit_count, moz_bookmarks.dateAdded, moz_places.url, moz_bookmarks.title from moz_places, moz_bookmarks where moz_places.id=moz_bookmarks.fk;")

(def whoosh-schema {"url" (ID :stored true :unique true) "title" (TEXT :stored true) "content_markdown" (TEXT :stored true) "date_added" (DATETIME :stored true) "fail_count" (NUMERIC :stored true)})

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
    (.read (urllib2.urlopen url))
    (catch [e urllib2.HTTPError] None)
    (catch [e urllib2.URLError] None)
    (catch [e httplib.BadStatusLine])))

(defn index-doc [index add-or-update doc]
  (let [[writer (index.writer)]]
    (apply (getattr writer (+ add-or-update "_document")) [] doc)
    (writer.commit)))

(defn index-bookmarks []
  (let [[bookmarks (load-bookmarks)]
        [index (load-whoosh-index)]
        [searcher (index.searcher)]
        [known-urls (dict-comp (get s "url") s [s (searcher.documents)])]
        [bookmarks-count (len bookmarks)]]
    (print (% "%d bookmarks" (len bookmarks)))
    (for [idx (range (len bookmarks))]
      (let [[[visits date_added url title hash] (get bookmarks idx)]
            [existing-doc (.get known-urls url {})]]
        ;(print w)
        ;(print index.schema)
        ;(print url (in url known-urls))
        (let [[fail-count (.get existing-doc "fail_count" nil)]]
          (if fail-count
            (print (% "fail count for %s is %d" (, url fail-count))))
          (when (or
                  (not existing-doc)
                  (and fail-count (< fail-count 5)))
            (let [[page (get-url url)]
                  [parsed (when page (html2text (unicode page)))]]
              (print (% "Indexing %s (%d / %d) %d%% done" (, url idx bookmarks-count (/ (* 100 idx) bookmarks-count))))
              (index-doc index
                         (if existing-doc "update" "add")
                         (if parsed
                           {"url" (unicode url) "title" (unicode title) "content_markdown" (unicode parsed) "date_added" (datetime.fromtimestamp (/ date_added 1000000)) "fail_count" nil}
                           {"url" (unicode url) "fail_count" (if fail-count (inc fail-count) 1)})))))))))

(defn perform-search [terms]
  (print terms))

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
    (cond
      [(in "--index" sys.argv) (index-bookmarks)]
      [(> (len sys.argv) 1) (perform-search (slice sys.argv 1))]
      [True (usage sys.argv)])
  )

