-- LA TABLE DE RONIT: סכמה, הרשאות ונתוני התחלה
-- להריץ פעם אחת ב-Supabase: SQL Editor > New query > הדבקה > Run

-- ========== טבלאות ==========
create table if not exists public.categories (
  id    text primary key,
  title text not null,
  sort  int  not null default 0
);

create table if not exists public.dishes (
  id          text primary key default gen_random_uuid()::text,
  category_id text not null references public.categories(id) on update cascade,
  name        text not null,
  description text not null default '',
  size        text not null default '',
  price       numeric(10,2) not null check (price >= 0),
  image_url   text,
  available   boolean not null default true,
  sort        int not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.orders (
  id            uuid primary key default gen_random_uuid(),
  created_at    timestamptz not null default now(),
  customer_name text,
  notes         text,
  items         jsonb not null,
  total         numeric(10,2) not null check (total >= 0),
  status        text not null default 'new' check (status in ('new','confirmed','done','cancelled'))
);

-- ========== אבטחה (RLS) ==========
alter table public.categories enable row level security;
alter table public.dishes     enable row level security;
alter table public.orders     enable row level security;

grant select on public.categories, public.dishes to anon;
grant insert on public.orders to anon;
grant all on public.categories, public.dishes, public.orders to authenticated;

-- גולשים: רואים תפריט, ויכולים רק ליצור הזמנה (לא לקרוא הזמנות של אחרים)
create policy "public read categories" on public.categories for select to anon using (true);
create policy "public read dishes"     on public.dishes     for select to anon using (available);
create policy "anyone can place order" on public.orders for insert to anon, authenticated
  with check (
    status = 'new'
    and jsonb_typeof(items) = 'array'
    and jsonb_array_length(items) between 1 and 60
    and char_length(coalesce(customer_name,'')) <= 200
    and char_length(coalesce(notes,'')) <= 1000
  );

-- רונית (משתמש מחובר): ניהול מלא
create policy "admin categories" on public.categories for all to authenticated using (true) with check (true);
create policy "admin dishes"     on public.dishes     for all to authenticated using (true) with check (true);
create policy "admin read orders"   on public.orders for select to authenticated using (true);
create policy "admin update orders" on public.orders for update to authenticated using (true) with check (true);
create policy "admin delete orders" on public.orders for delete to authenticated using (true);

-- ========== אחסון תמונות ==========
insert into storage.buckets (id, name, public) values ('dish-images', 'dish-images', true)
on conflict (id) do nothing;

create policy "admin upload dish images" on storage.objects for insert to authenticated with check (bucket_id = 'dish-images');
create policy "admin update dish images" on storage.objects for update to authenticated using (bucket_id = 'dish-images');
create policy "admin delete dish images" on storage.objects for delete to authenticated using (bucket_id = 'dish-images');

-- ========== נתוני התחלה ==========
insert into public.categories (id, title, sort) values
  ('salads', 'סלטים', 1),
  ('mains', 'מנות עיקריות', 2),
  ('pastry', 'פטיסרי', 3)
on conflict (id) do nothing;

insert into public.dishes (id, category_id, name, description, size, price, image_url, sort) values
  ('s1', 'salads', 'קפרזה מוצרלה וארוגולה', 'כדורי מוצרלה טריים, עגבניות שרי בשלות, ארוגולה ועלים אדומים, שמן זית כתית ופלפל שחור גרוס.', 'קערה גדולה, מספיקה ל-6-8 סועדים', 140, 's1.jpg', 1),
  ('s2', 'salads', 'חלומי פריך וירוקים', 'קוביות חלומי מוקפצות עד הזהבה על עלים מתולתלים, עגבנייה ומלפפון, ברוטב יוגורט-לימון.', 'קערה גדולה, מספיקה ל-4-6 סועדים', 120, 's2.jpg', 2),
  ('s3', 'salads', 'טונה, צנונית ועשבי תיבול', 'נתחי טונה בשמן זית, צנוניות פריכות, מלפפון ופטרוזיליה ברוטב שמנת חמוצה קליל.', 'קערה גדולה, מספיקה ל-4-6 סועדים', 130, 's3.jpg', 3),
  ('s4', 'salads', 'סלט ירוק עם פלפל צהוב', 'חסות מתולתלת פריכה, עגבניות, מלפפון ופלפל צהוב מתוק ברוטב לימון ושמן זית.', 'קערה גדולה, מספיקה ל-6-8 סועדים', 90, 's4.jpg', 4),
  ('s5', 'salads', 'סלט סלרי ופקאן מסוכר', 'עלי וגבעולי סלרי קצוצים דק עם פקאן מסוכר וויניגרט חמצמץ.', 'קערה גדולה, מספיקה ל-4-6 סועדים', 110, 's5.jpg', 5),
  ('s6', 'salads', 'פלטת קרודיטה ביצים ואבוקדו', 'אבוקדו פרוס, ביצים קשות, עגבניות שרי צהובות ואדומות, צנוניות, פטריות, זיתים ופלפלים חריפים קטנים.', 'פלטה גדולה, מספיקה ל-8-10 סועדים', 170, 's6.jpg', 6),
  ('m1', 'mains', 'קרפצ׳יו סלמון וצ׳ילי', 'פרוסות סלמון טרי, צנונית, שמן זית כתית, צ׳ילי טרי, בצל ירוק וכוסברה.', 'מגש של 1 ק״ג, מספיק ל-6-8 סועדים', 260, 'm1.jpg', 1),
  ('m2', 'mains', 'שיפודי ירקות צלויים', 'בטטה, קישוא, פלפלים ובצל סגול צלויים בתנור עם תבלינים. 20 שיפודים במגש.', 'מגש של 20 שיפודים, מספיק ל-8-10 סועדים', 190, 'm2.jpg', 2),
  ('m3', 'mains', 'פסטה פרפלה בשמנת ועשבי תיבול', 'פרפלה אל דנטה ברוטב שמנת קטיפתי עם עשבי תיבול טריים.', 'תבנית גדולה, מספיקה ל-6-8 סועדים', 120, 'm3.jpg', 3),
  ('m4', 'mains', 'סושי סלמון ואבוקדו', 'רולים עם סלמון, אבוקדו ומלפפון באורז סושי. מוגשים עם סויה, ג׳ינג׳ר וואסבי.', '2 מגשים, 48 יחידות, מספיק ל-6-8 סועדים', 240, 'm4.jpg', 4),
  ('m5', 'mains', 'ירקות קלויים בתנור', 'תירס, עגבניות, קישוא ובצל סגול צלויים עם שמן זית, מלח גס ופלפל שחור.', 'תבנית גדולה, מספיקה ל-6-8 סועדים', 130, 'm5.jpg', 5),
  ('m6', 'mains', 'פלפלים צלויים בפסטו', 'חצאי פלפלים אדומים וצהובים צלויים, מצופים בפסטו עשבים וקלויים עד הקרמל.', 'תבנית גדולה, מספיקה ל-6-8 סועדים', 140, 'm6.jpg', 6),
  ('m7', 'mains', 'קישואים ובטטה צלויים', 'פרוסות קישוא ובטטה בתיבול חם, צלויות בתנור עד שמשתבשות בקצוות.', 'מגש גדול, מספיק ל-8-10 סועדים', 120, 'm7.jpg', 7),
  ('m8', 'mains', 'סלמון מעושן ומלפפון', 'סלמון מעושן פרוס דק על סרטי מלפפון, עם נבטים ופלפל שחור.', 'קערת הגשה, מספיקה ל-6-8 סועדים', 190, 'm8.jpg', 8),
  ('p1', 'pastry', 'טארט פיסטוק', 'בצק פריך וקרם פיסטוק עשיר, מסוכך בפיסטוק קלוף קצוץ.', 'טארט בקוטר 26 ס״מ, 10-12 מנות', 190, 'p1.jpg', 1),
  ('p2', 'pastry', 'פאי לימון ומרנג', 'בסיס חמאתי, קרם לימון חמצמץ ומרנג שרוף קלות. 12 חתיכות במגש.', 'מגש של 12 חתיכות', 150, 'p2.jpg', 2),
  ('p3', 'pastry', 'עוגת גבינה ותותים', 'עוגת גבינה אפויה בטקסטורה קטיפתית, שכבת שמנת וניל ותותים טריים.', 'עוגה בקוטר 24 ס״מ, 12 מנות', 180, 'p3.jpg', 3),
  ('p4', 'pastry', 'סופגניות אישיות בקרם פירות', 'סופגניות אפויות מטוגנות בסוכר גרגרי, עם קישוט קרם ורוד.', '12 יחידות', 110, 'p4.jpg', 4),
  ('p5', 'pastry', 'עוגת שכבות וניל ותות', 'שכבות עוגת וניל רכה עם קרם שמנת, בעיצוב נייקד, ותותים טריים.', 'עוגה בקוטר 20 ס״מ, 10-12 מנות', 200, 'p5.jpg', 5),
  ('p6', 'pastry', 'צ׳ורוס בסוכר', 'צ׳ורוס טריים וזהובים, מצופים בסוכר גרגרי.', '20 יחידות', 70, 'p6.jpg', 6)
on conflict (id) do nothing;
