(import
  [sqlite3]
  [hashlib [sha256]]
  [glob [glob]]
  [os [path]])

(def bookmarks-query "select moz_places.visit_count, moz_bookmarks.dateAdded, moz_places.url, moz_bookmarks.title from moz_places, moz_bookmarks where moz_places.id=moz_bookmarks.fk;")

; load up the default places.sqlite
(let [[places-sqlite (glob (path.expanduser (path.join "~" ".mozilla" "firefox" "*.default" "places.sqlite")))]
      [db (if places-sqlite (sqlite3.connect (get places-sqlite 0)))]
      [c (if places-sqlite (db.cursor))]]
  (if db
    (for [r (c.execute bookmarks-query)]
      (print r)
      (print (.hexdigest (sha256 (get r 2)))))))

