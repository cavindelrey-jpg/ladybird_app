create table public.daily_learning_streaks (
    user_id uuid references auth.users(id) on delete cascade primary key,
    current_streak int not null default 0,
    longest_streak int not null default 0,
    last_completed_date date
);
alter table public.daily_learning_streaks enable row level security;
create policy "Users can view their own streak."
    on public.daily_learning_streaks for select
    using ( auth.uid() = user_id );
create policy "Users can update their own streak."
    on public.daily_learning_streaks for insert
    with check ( auth.uid() = user_id );
create policy "Users can update their own streak.."
    on public.daily_learning_streaks for update
    using ( auth.uid() = user_id );
