-- ============================================================================
-- greenhills_app/ladybird_app's magazine XP model (production_plan.md
-- §4.5): a one-time, 24h-delayed, formula-based settlement per article
-- (views/50 + likes*2 + comments*5 + shares*4, capped), entirely separate
-- from academia-cameroon's own "2 XP per unique read, pending_author_xp"
-- mechanism (record_article_read / settle_pending_author_xp, unchanged
-- above) -- both read/write different columns on the same shared
-- magazine_articles row, so they coexist without conflict. Academia-
-- cameroon never calls settle_magazine_xp_if_due; these columns are
-- simply always false/0/unused there.
-- ============================================================================

-- Same unique-per-user dedup as record_article_read, for shares.
create or replace function public.record_article_share(p_article_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if; -- guests don't earn/track shares
  insert into public.article_shares (article_id, user_id) values (p_article_id, auth.uid())
    on conflict (article_id, user_id) do nothing;
  if found then
    update public.magazine_articles set share_count = share_count + 1 where id = p_article_id;
  end if;
end;
$$;

-- Computes and marks the one-time formula settlement if due (article at
-- least 24h old and not yet settled). Returns the awarded amount and
-- author id so the caller can pass them to award_xp() -- kept as a
-- separate client-side step (same as academia-cameroon's own
-- settle_pending_author_xp -> AuthService.addXp() split) rather than
-- calling award_xp from inside this function, so this RPC doesn't need
-- to know about kDailyXpCap/quiz-vs-magazine category logic itself.
create or replace function public.settle_magazine_xp_if_due(p_article_id uuid)
returns table (out_author_id uuid, out_amount integer)
language plpgsql security definer set search_path = public as $$
declare
  v_author_id uuid;
  v_created_at timestamptz;
  v_settled boolean;
  v_reads integer;
  v_likes integer;
  v_comments integer;
  v_shares integer;
  v_amount integer;
begin
  select author_id, created_at, magazine_xp_settled, read_count, like_count, comment_count, share_count
    into v_author_id, v_created_at, v_settled, v_reads, v_likes, v_comments, v_shares
    from public.magazine_articles where id = p_article_id for update;

  if not found or v_settled or now() - v_created_at < interval '24 hours' then
    return;
  end if;

  -- 80 mirrors kMagazinePerPostXpCap in lib/models/xp_transaction.dart --
  -- keep both in sync if that constant ever changes.
  v_amount := greatest(0, least(80, round(
    (v_reads::numeric / 50) + (v_likes * 2) + (v_comments * 5) + (v_shares * 4)
  )::integer));

  update public.magazine_articles set magazine_xp_settled = true where id = p_article_id;

  if v_amount > 0 and v_author_id is not null then
    return query select v_author_id, v_amount;
  end if;
end;
$$;
