import { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

export const authOptions: NextAuthOptions = {
  secret: process.env.NEXTAUTH_SECRET || process.env.SESSION_SECRET || "glint-default-secure-secret-2026",
  providers: [
    CredentialsProvider({
      name: "Admin Login",
      credentials: {
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        const adminPassword = process.env.ADMIN_PASSWORD || "glint-admin-2026";
        
        if (credentials?.password === adminPassword) {
          return { id: "1", name: "Admin", email: "admin@glint.app" };
        }
        return null;
      }
    })
  ],
  pages: {
    signIn: '/admin/login',
  },
  session: {
    strategy: "jwt"
  },
  callbacks: {
    async session({ session, token }) {
      if (session.user) {
        // @ts-ignore
        session.user.id = token.sub;
      }
      return session;
    }
  }
};
