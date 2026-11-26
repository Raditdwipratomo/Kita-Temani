import { createClient, SupabaseClient, User } from 'npm:@supabase/supabase-js@2';

export interface AuthContext {
  client: SupabaseClient;
  adminClient: SupabaseClient;
  user: User;
}

export async function requireAuthenticatedUser(req: Request): Promise<AuthContext | null> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? anonKey;
  const authHeader = req.headers.get('Authorization') ?? '';

  if (!supabaseUrl || !anonKey || !authHeader) {
    return null;
  }

  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) {
    return null;
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  return { client, adminClient, user };
}
