-- Restrict communication creation to the authenticated sender identity.
drop policy if exists "authenticated send communications" on public.trip_communications;
create policy "authenticated send communications" on public.trip_communications
 for insert to authenticated with check(sender_id=auth.uid());
