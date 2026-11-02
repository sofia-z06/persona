-- Tests des tables articles et sent_articles.
-- Tout est fait dans une transaction annulée à la fin : la base reste propre.
-- Lancer :
--   docker compose exec -T postgres psql -U persona -d persona -v ON_ERROR_STOP=1 < tests/db/test_articles.sql
-- Si tout passe, la dernière ligne affichée est : NOTICE:  tous les tests articles / sent_articles passent

BEGIN;

-- utilisateur de test (adapter les colonnes si le schéma de users change)
INSERT INTO users (email, consent_at) VALUES ('test-articles@example.com', NOW());

-- articles de test
INSERT INTO articles (url, title, summary, source, tags) VALUES
  ('https://example.com/ia-1',   'Nouveau modèle open source', 'Résumé 1', 'example', ARRAY['ia','tech']),
  ('https://example.com/eco-1',  'La BCE baisse ses taux',     'Résumé 2', 'example', ARRAY['economie']),
  ('https://example.com/sport-1','Résultats de la Ligue 1',    NULL,       'example', '{}');

DO $$
DECLARE
  u  INTEGER := (SELECT id FROM users    WHERE email = 'test-articles@example.com');
  a1 INTEGER := (SELECT id FROM articles WHERE url = 'https://example.com/ia-1');
  a2 INTEGER := (SELECT id FROM articles WHERE url = 'https://example.com/eco-1');
  n  INT;
BEGIN
  -- 1. valeurs par défaut
  PERFORM 1 FROM articles WHERE url = 'https://example.com/sport-1' AND tags = '{}' AND fetched_at IS NOT NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'ÉCHEC : valeurs par défaut de articles'; END IF;

  -- 2. url unique
  BEGIN
    INSERT INTO articles (url, title) VALUES ('https://example.com/ia-1', 'Doublon');
    RAISE EXCEPTION 'ÉCHEC : url en double acceptée';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  -- 3. url invalide refusée
  BEGIN
    INSERT INTO articles (url, title) VALUES ('javascript:alert(1)', 'Mauvaise url');
    RAISE EXCEPTION 'ÉCHEC : url non http(s) acceptée';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- 4. recherche par tag
  SELECT count(*) INTO n FROM articles WHERE tags && ARRAY['ia'];
  IF n <> 1 THEN RAISE EXCEPTION 'ÉCHEC : recherche par tag (% trouvé(s))', n; END IF;

  -- 5. un article envoyé une seule fois par user
  INSERT INTO sent_articles (user_id, article_id) VALUES (u, a1), (u, a2);
  BEGIN
    INSERT INTO sent_articles (user_id, article_id) VALUES (u, a1);
    RAISE EXCEPTION 'ÉCHEC : même article envoyé deux fois au même user';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  -- 6. clés étrangères : user ou article inexistant refusé
  BEGIN
    INSERT INTO sent_articles (user_id, article_id) VALUES (-1, a1);
    RAISE EXCEPTION 'ÉCHEC : user inexistant accepté';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO sent_articles (user_id, article_id) VALUES (u, -1);
    RAISE EXCEPTION 'ÉCHEC : article inexistant accepté';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  -- 7. supprimer un article supprime son historique d'envoi
  DELETE FROM articles WHERE id = a2;
  SELECT count(*) INTO n FROM sent_articles WHERE article_id = a2;
  IF n <> 0 THEN RAISE EXCEPTION 'ÉCHEC : cascade articles -> sent_articles'; END IF;

  -- 8. supprimer un user supprime son historique d'envoi
  DELETE FROM users WHERE id = u;
  SELECT count(*) INTO n FROM sent_articles WHERE user_id = u;
  IF n <> 0 THEN RAISE EXCEPTION 'ÉCHEC : cascade users -> sent_articles'; END IF;

  RAISE NOTICE 'tous les tests articles / sent_articles passent';
END $$;

ROLLBACK;
