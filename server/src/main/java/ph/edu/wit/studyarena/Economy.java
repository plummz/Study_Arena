package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.time.*;
import java.util.*;

final class Economy {
  final Api a;
  final Db d;

  Economy(Api a) {
    this.a = a;
    d = a.db;
    a.add(
        "GET",
        "/api/shop",
        "student",
        false,
        "—",
        "{items:[CatalogItem],inventory,claims,wallet}",
        "",
        r -> {
          List<Map<String, Object>> items =
              d.all(
                  "SELECT * FROM catalog WHERE active=1 AND (kind!='prize' OR ?=1) AND"
                      + " (adult_only=0 OR ?='adult') ORDER BY price",
                  d.flag("prizes") ? 1 : 0,
                  r.user.get("age_band"));
          return map(
              "items",
              items,
              "inventory",
              d.all(
                  "SELECT i.*,c.title,c.kind,c.value FROM inventory i JOIN catalog c ON"
                      + " i.item_id=c.id WHERE user_id=?",
                  r.uid()),
              "claims",
              d.all(
                  "SELECT c.*,x.title FROM claims c JOIN catalog x ON c.item_id=x.id WHERE"
                      + " c.user_id=?",
                  r.uid()),
              "wallet",
              wallet(r.uid()));
        });
    a.add(
        "POST",
        "/api/shop/{id}/purchase",
        "student",
        true,
        "{rules_version?}",
        "{inventory?|claim?,wallet}",
        "INSUFFICIENT_FUNDS,OUT_OF_STOCK,AGE_RESTRICTED,EMAIL_UNVERIFIED,RULES_CHANGED,ALREADY_CLAIMED",
        r -> {
          Map<String, Object> item = d.need("SELECT * FROM catalog WHERE id=? AND active=1", r.p());
          String kind = str(item, "kind");
          require(
              num(item, "adult_only") == 0 || str(r.user, "age_band").equals("adult"),
              403,
              "AGE_RESTRICTED",
              "This item is available only to verified adults.");
          if (kind.equals("prize")) {
            r.flag("prizes");
            require(
                num(r.user, "verified") == 1, 403, "EMAIL_UNVERIFIED", "Verify your email first.");
            require(
                num(r.body, "rules_version") == num(item, "rules_version"),
                409,
                "RULES_CHANGED",
                "Read and accept the current published rules.");
            require(
                d.one("SELECT id FROM claims WHERE user_id=? AND item_id=?", r.uid(), r.p())
                    == null,
                409,
                "ALREADY_CLAIMED",
                "Only one claim per student per prize offer.");
          } else {
            Map<String, Object> owned =
                d.one("SELECT * FROM inventory WHERE user_id=? AND item_id=?", r.uid(), r.p());
            if (owned != null && num(owned, "consumed") == 0)
              return map("inventory", owned, "wallet", wallet(r.uid()));
          }
          int price = (int) num(item, "price");
          require(
              num(wallet(r.uid()), "coins") >= price,
              409,
              "INSUFFICIENT_FUNDS",
              "You need more study coins for this item.");
          require(
              item.get("stock") == null || num(item, "stock") > 0,
              409,
              "OUT_OF_STOCK",
              "This item has run out of stock.");
          String purchase = id();
          ledger(
              r.uid(),
              0,
              -price,
              "purchase:" + purchase,
              "Purchased " + str(item, "title"),
              r.uid());
          if (item.get("stock") != null)
            d.exec("UPDATE catalog SET stock=stock-1 WHERE id=? AND stock>0", r.p());
          if (kind.equals("prize")) {
            d.insert(
                "claims",
                map(
                    "id",
                    purchase,
                    "user_id",
                    r.uid(),
                    "item_id",
                    r.p(),
                    "state",
                    "pending",
                    "rules_version",
                    item.get("rules_version"),
                    "rules_snapshot",
                    json(
                        map(
                            "rules",
                            item.get("rules"),
                            "sponsor",
                            item.get("sponsor"),
                            "price",
                            price,
                            "adult_only",
                            item.get("adult_only"))),
                    "created",
                    now(),
                    "updated",
                    now()));
            d.audit(
                r.uid(),
                "claim_submitted",
                purchase,
                "Accepted rules version " + item.get("rules_version"));
            return map(
                "claim",
                d.need("SELECT * FROM claims WHERE id=?", purchase),
                "wallet",
                wallet(r.uid()));
          }
          d.exec(
              "INSERT INTO inventory VALUES(?,?,?,0,0) ON CONFLICT(user_id,item_id) DO UPDATE SET"
                  + " acquired=excluded.acquired,consumed=0",
              r.uid(),
              r.p(),
              now());
          notify(r.uid(), "rewards", "Added to your inventory: " + str(item, "title"));
          return map(
              "inventory",
              d.need("SELECT * FROM inventory WHERE user_id=? AND item_id=?", r.uid(), r.p()),
              "wallet",
              wallet(r.uid()));
        });
    a.add(
        "POST",
        "/api/inventory/{id}/equip",
        "student",
        true,
        "{}",
        "{ok}",
        "NOT_OWNED,INVALID_ITEM",
        r -> {
          Map<String, Object> item =
              d.need(
                  "SELECT c.* FROM catalog c JOIN inventory i ON c.id=i.item_id WHERE i.user_id=?"
                      + " AND i.item_id=? AND i.consumed=0",
                  r.uid(),
                  r.p());
          require(
              Set.of("skin", "border", "hat", "theme").contains(str(item, "kind")),
              422,
              "INVALID_ITEM",
              "This item cannot be equipped.");
          d.exec(
              "UPDATE inventory SET equipped=0 WHERE user_id=? AND item_id IN (SELECT id FROM"
                  + " catalog WHERE kind=?)",
              r.uid(),
              item.get("kind"));
          d.exec("UPDATE inventory SET equipped=1 WHERE user_id=? AND item_id=?", r.uid(), r.p());
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/inventory/{id}/freeze",
        "student",
        true,
        "{}",
        "{ok,day}",
        "INVALID_ITEM,ALREADY_PROTECTED",
        r -> {
          d.need(
              "SELECT c.* FROM catalog c JOIN inventory i ON c.id=i.item_id WHERE i.user_id=? AND"
                  + " i.item_id=? AND c.kind='freeze' AND i.consumed=0",
              r.uid(),
              r.p());
          String day = LocalDate.now(ZoneId.of(str(r.user, "timezone"))).minusDays(1).toString();
          require(
              d.one("SELECT day FROM streak_days WHERE user_id=? AND day=?", r.uid(), day) == null,
              409,
              "ALREADY_PROTECTED",
              "Yesterday is already protected or studied.");
          d.exec("UPDATE inventory SET consumed=1 WHERE user_id=? AND item_id=?", r.uid(), r.p());
          d.exec("INSERT INTO streak_days VALUES(?,?,?,?)", r.uid(), day, "freeze", now());
          return map("ok", true, "day", day);
        });
    a.add(
        "POST",
        "/api/claims/{id}/cancel",
        "student",
        true,
        "{}",
        "{claim,wallet}",
        "INVALID_STATE",
        r -> {
          Map<String, Object> claim =
              d.need("SELECT * FROM claims WHERE id=? AND user_id=?", r.p(), r.uid());
          require(
              Set.of("pending", "approved").contains(str(claim, "state")),
              409,
              "INVALID_STATE",
              "Claim cannot be cancelled now.");
          refundClaim(claim, "cancelled", r.uid(), "Student cancelled claim");
          return map(
              "claim", d.need("SELECT * FROM claims WHERE id=?", r.p()), "wallet", wallet(r.uid()));
        });
    a.add(
        "GET",
        "/api/notifications",
        "student",
        false,
        "—",
        "{items:[Notification],settings}",
        "",
        r ->
            map(
                "items",
                d.all(
                    "SELECT * FROM notifications WHERE user_id=? ORDER BY created DESC LIMIT 50",
                    r.uid()),
                "settings",
                d.need("SELECT * FROM notification_settings WHERE user_id=?", r.uid())));
    a.add(
        "PUT",
        "/api/notifications/settings",
        "student",
        true,
        "{reminders,streak,invitations,challenges,rewards,quiet_start,quiet_end,reminder_time,daily_cap}",
        "{settings}",
        "VALIDATION",
        r -> {
          String time = text(r.body, "reminder_time", 5, 5);
          try {
            LocalTime.parse(time);
          } catch (Exception ex) {
            throw new Fault(422, "VALIDATION", "Choose a valid reminder time.");
          }
          d.exec(
              "UPDATE notification_settings SET"
                  + " reminders=?,streak=?,invitations=?,challenges=?,rewards=?,quiet_start=?,quiet_end=?,reminder_time=?,daily_cap=?"
                  + " WHERE user_id=?",
              yes(r.body, "reminders") ? 1 : 0,
              yes(r.body, "streak") ? 1 : 0,
              yes(r.body, "invitations") ? 1 : 0,
              yes(r.body, "challenges") && num(r.user, "competition") == 1 ? 1 : 0,
              yes(r.body, "rewards") ? 1 : 0,
              integer(r.body, "quiet_start", 0, 23, 22),
              integer(r.body, "quiet_end", 0, 23, 7),
              time,
              integer(r.body, "daily_cap", 0, 3, 3),
              r.uid());
          return map(
              "settings", d.need("SELECT * FROM notification_settings WHERE user_id=?", r.uid()));
        });
    a.add(
        "POST",
        "/api/notifications/{id}/read",
        "student",
        true,
        "{}",
        "{ok}",
        "",
        r -> {
          d.exec("UPDATE notifications SET read=1 WHERE id=? AND user_id=?", r.p(), r.uid());
          return map("ok", true);
        });
    a.add(
        "GET",
        "/api/wallet",
        "student",
        false,
        "?offset=&limit=",
        "{wallet,ledger:[LedgerEntry]}",
        "",
        r ->
            map(
                "wallet",
                wallet(r.uid()),
                "ledger",
                d.all(
                    "SELECT id,xp,coins,origin,reason,created FROM ledger WHERE user_id=? ORDER BY"
                        + " created DESC LIMIT ? OFFSET ?",
                    r.uid(),
                    r.limit(),
                    r.offset())));
  }

  Map<String, Object> wallet(String uid) {
    Map<String, Object> w =
        d.need(
            "SELECT coalesce(sum(xp),0) AS xp,coalesce(sum(coins),0) AS coins FROM ledger WHERE"
                + " user_id=?",
            uid);
    int xp = (int) num(w, "xp");
    w.put("level", Math.min(50, 1 + Math.max(0, xp) / 100));
    w.put("next_level_xp", Math.min(4900, (1 + Math.max(0, xp) / 100) * 100));
    w.put(
        "unlocks",
        List.of(
            map("level", 1, "title", "All core study tools"),
            map("level", 5, "title", "Scholar badge"),
            map("level", 10, "title", "Steady learner badge"),
            map("level", 50, "title", "Master learner badge")));
    return w;
  }

  void ledger(String uid, int xp, int coins, String origin, String reason, String actor) {
    d.exec(
        "INSERT OR IGNORE INTO ledger VALUES(?,?,?,?,?,?,?,?)",
        id(),
        uid,
        xp,
        coins,
        origin,
        reason,
        now(),
        actor);
  }

  void award(String uid, String origin, int xp, int coins, String reason) {
    int
        xpToday =
            (int)
                d.scalar(
                    "SELECT coalesce(sum(xp),0) FROM ledger WHERE user_id=? AND xp>0 AND created>?",
                    uid,
                    now() - 86400),
        coinsToday =
            (int)
                d.scalar(
                    "SELECT coalesce(sum(coins),0) FROM ledger WHERE user_id=? AND coins>0 AND"
                        + " origin NOT LIKE 'refund:%' AND created>?",
                    uid, now() - 86400);
    xp = Math.min(xp, Math.max(0, 500 - xpToday));
    coins = Math.min(coins, Math.max(0, 100 - coinsToday));
    ledger(uid, xp, coins, origin, reason, null);
    int level = (int) num(wallet(uid), "level");
    for (int threshold : List.of(5, 10, 50))
      if (level >= threshold)
        d.exec("INSERT OR IGNORE INTO badges VALUES(?,?,?)", uid, "Level " + threshold, now());
  }

  void refundClaim(Map<String, Object> claim, String state, String actor, String reason) {
    Map<String, Object> rules = obj(str(claim, "rules_snapshot"));
    ledger(
        str(claim, "user_id"),
        0,
        (int) num(rules, "price"),
        "refund:" + str(claim, "id"),
        reason,
        actor);
    d.exec(
        "UPDATE catalog SET stock=stock+1 WHERE id=? AND stock IS NOT NULL", claim.get("item_id"));
    d.exec(
        "UPDATE claims SET state=?,updated=?,reviewer=?,reason=? WHERE id=?",
        state,
        now(),
        actor,
        reason,
        claim.get("id"));
    d.audit(actor, "claim_" + state, str(claim, "id"), reason);
  }

  void notify(String uid, String category, String body) {
    Map<String, Object> s =
        d.one(
            "SELECT n.*,u.timezone,u.competition FROM notification_settings n JOIN users u ON"
                + " u.id=n.user_id WHERE n.user_id=? AND u.delete_after IS NULL",
            uid);
    if (s == null
        || !Set.of("reminders", "streak", "invitations", "challenges", "rewards").contains(category)
        || num(s, category) == 0
        || category.equals("challenges") && num(s, "competition") == 0) return;
    ZonedDateTime t = ZonedDateTime.now(ZoneId.of(str(s, "timezone")));
    int h = t.getHour(), start = (int) num(s, "quiet_start"), end = (int) num(s, "quiet_end");
    boolean quiet = start < end ? h >= start && h < end : start > end && (h >= start || h < end);
    if (quiet
        || d.scalar(
                "SELECT count(*) FROM notifications WHERE user_id=? AND day=?",
                uid,
                t.toLocalDate().toString())
            >= Math.max(0, num(s, "daily_cap") - (num(s, "reminders") == 1 ? 1 : 0))) return;
    d.insert(
        "notifications",
        map(
            "id",
            id(),
            "user_id",
            uid,
            "category",
            category,
            "body",
            body,
            "created",
            now(),
            "day",
            t.toLocalDate().toString()));
  }
}
