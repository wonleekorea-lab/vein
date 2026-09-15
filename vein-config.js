// =============================================================
// journaling（vein） — 外部サービス設定（公開して安全な値だけ）
// =============================================================
// ここに置いてよいのは anon key（公開前提の鍵）だけ。
// service_role key や DBパスワードは絶対に置かない（RLSを迂回できてしまう）。
// anon key が公開でも安全なのは、Supabase側で Row Level Security を有効にし、
// 「自分の行しか読み書きできない」ポリシーを張っているため（supabase/schema.sql）。
//
// 空のままでもアプリは完全に動作する（この端末の中だけ＝従来どおり）。
// 値が入っていると、設定（···）に sync が出て、入れば端末をまたいで残る。
//
// Sokugan と同じプロジェクトを使っている。だから **同じメールとパスワードで入れる**。
window.VEIN_CONFIG = {
  supabaseUrl: "https://weanydapeersamxlphku.supabase.co",
  supabaseAnonKey: "sb_publishable_r6wpQOCf9TI3jPDYMlCl6A_dmIYfswF"
};
