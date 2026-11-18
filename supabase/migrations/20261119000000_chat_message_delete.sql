-- Enable own-message deletion in team chat channels (`public.chat_messages`).
-- Users may only delete messages they authored (`auth.uid() = user_id`).

grant delete on table public.chat_messages to authenticated;

drop policy if exists chat_delete_own on public.chat_messages;
create policy chat_delete_own on public.chat_messages
  for delete to authenticated
  using (auth.uid() = user_id);
