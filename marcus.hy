(import
  [sys]
  [sqlite3]
  [hashlib [sha256]]
  [glob [glob]]
  [os [path]])

(def bookmarks-query "select moz_places.visit_count, moz_bookmarks.dateAdded, moz_places.url, moz_bookmarks.title from moz_places, moz_bookmarks where moz_places.id=moz_bookmarks.fk;")

(defn load-bookmarks []
  ; load up the default places.sqlite
  (let [[places-sqlite (glob (path.expanduser (path.join "~" ".mozilla" "firefox" "*.default" "places.sqlite")))]
        [db (try (sqlite3.connect (get places-sqlite 0)) (catch [e Exception] (sys.exit "Could not find or open the places.sqlite file.")))]
        [c (db.cursor)]]
    (list-comp
      (+ (list r) [(.hexdigest (sha256 (get r 2)))])
      [r (c.execute bookmarks-query)])))

(if (= __name__ "__main__")
  (print (load-bookmarks)))

