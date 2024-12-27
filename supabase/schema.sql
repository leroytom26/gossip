-- Enable necessary extensions
create extension if not exists "uuid-ossp";

-- Clean up existing tables if needed (be careful with this in production)
drop table if exists feedback;
drop table if exists partnerships;
drop table if exists partners;
drop table if exists reward_redemptions;
drop table if exists rewards;
drop table if exists session_participants;
drop table if exists sessions;
drop table if exists profiles;

-- Create tables
create table profiles (
    id uuid primary key default uuid_generate_v4(),
    twitter_id text unique not null,
    username text not null,
    full_name text,
    email text,
    avatar_url text,
    bio text,
    points integer default 0,
    is_admin boolean default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table sessions (
    id uuid primary key default uuid_generate_v4(),
    title text not null,
    description text,
    twitter_space_id text unique,
    scheduled_start timestamp with time zone not null,
    scheduled_end timestamp with time zone not null,
    status text check (status in ('scheduled', 'live', 'ended', 'cancelled')) default 'scheduled',
    host_id uuid references profiles(id) not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table session_participants (
    id uuid primary key default uuid_generate_v4(),
    session_id uuid references sessions(id) on delete cascade not null,
    profile_id uuid references profiles(id) on delete cascade not null,
    join_time timestamp with time zone default timezone('utc'::text, now()),
    leave_time timestamp with time zone,
    points_earned integer default 0,
    unique(session_id, profile_id)
);

create table rewards (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    points_required integer not null,
    quantity_available integer default -1, -- -1 means unlimited
    reward_type text check (reward_type in ('airtime', 'transport', 'other')) not null,
    is_active boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table reward_redemptions (
    id uuid primary key default uuid_generate_v4(),
    reward_id uuid references rewards(id) not null,
    profile_id uuid references profiles(id) not null,
    points_spent integer not null,
    status text check (status in ('pending', 'completed', 'failed')) default 'pending',
    redemption_date timestamp with time zone default timezone('utc'::text, now()) not null
);

create table partners (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    description text,
    logo_url text,
    website_url text,
    contact_email text,
    contact_phone text,
    is_active boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table partnerships (
    id uuid primary key default uuid_generate_v4(),
    partner_id uuid references partners(id) not null,
    session_id uuid references sessions(id),
    contribution_type text check (contribution_type in ('sponsorship', 'rewards', 'other')) not null,
    contribution_details text,
    start_date timestamp with time zone not null,
    end_date timestamp with time zone,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table feedback (
    id uuid primary key default uuid_generate_v4(),
    session_id uuid references sessions(id) on delete cascade not null,
    profile_id uuid references profiles(id) on delete cascade not null,
    rating integer check (rating >= 1 and rating <= 5),
    comment text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(session_id, profile_id)
);

-- Create indexes for better query performance
create index idx_profiles_twitter_id on profiles(twitter_id);
create index idx_sessions_host_id on sessions(host_id);
create index idx_sessions_status on sessions(status);
create index idx_session_participants_session_id on session_participants(session_id);
create index idx_session_participants_profile_id on session_participants(profile_id);
create index idx_reward_redemptions_profile_id on reward_redemptions(profile_id);
create index idx_partnerships_partner_id on partnerships(partner_id);
create index idx_partnerships_session_id on partnerships(session_id);
create index idx_feedback_session_id on feedback(session_id);

-- Enable Row Level Security
alter table profiles enable row level security;
alter table sessions enable row level security;
alter table session_participants enable row level security;
alter table rewards enable row level security;
alter table reward_redemptions enable row level security;
alter table partners enable row level security;
alter table partnerships enable row level security;
alter table feedback enable row level security;

-- Create policies
-- Note: These are basic policies, you might want to adjust them based on your specific requirements

-- Profiles: Users can read all profiles but only update their own
create policy "Profiles are viewable by everyone"
    on profiles for select
    using (true);

create policy "Users can update own profile"
    on profiles for update
    using (auth.uid() = id);

-- Sessions: Everyone can view sessions, only admins can create/update
create policy "Sessions are viewable by everyone"
    on sessions for select
    using (true);

create policy "Only admins can create sessions"
    on sessions for insert
    with check ((select is_admin from profiles where id = auth.uid()));

-- Insert some test data
insert into profiles (twitter_id, username, full_name, is_admin, points)
values 
    ('12345', 'brother_elkana', 'Brother Elkana', true, 1000),
    ('23456', 'test_user1', 'Test User 1', false, 500),
    ('34567', 'test_user2', 'Test User 2', false, 250);

insert into sessions (title, description, scheduled_start, scheduled_end, host_id)
values 
    (
        'Understanding Relationships in Modern Times',
        'A deep dive into maintaining healthy relationships in the digital age',
        now() + interval '1 day',
        now() + interval '1 day' + interval '2 hours',
        (select id from profiles where username = 'brother_elkana')
    );

insert into rewards (name, description, points_required, reward_type)
values 
    ('Airtime Bundle', '500MB data bundle', 100, 'airtime'),
    ('Transport Voucher', 'Uber ride voucher', 200, 'transport');

-- More test data can be added as needed 

-- Drop existing policies if any
drop policy if exists "Allow insert for authenticated users" on profiles;
drop policy if exists "Allow users to update own profile" on profiles;
drop policy if exists "Allow users to read all profiles" on profiles;

-- Create new policies
create policy "Allow insert during auth"
  on profiles for insert
  with check (true);  -- Allow all inserts initially

create policy "Allow users to update own profile"
  on profiles for update
  using (auth.uid()::text = id::text);

create policy "Allow users to read all profiles"
  on profiles for select
  using (true); 