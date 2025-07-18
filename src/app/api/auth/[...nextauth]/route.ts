import NextAuth from "next-auth";
import CognitoProvider from "next-auth/providers/cognito";
import CredentialsProvider from "next-auth/providers/credentials";

const handler = NextAuth({
  providers: [
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID!,
      clientSecret: process.env.COGNITO_CLIENT_SECRET!,
      issuer: process.env.COGNITO_ISSUER,
    }),
    CredentialsProvider({
      name: "Demo",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        // Demo user for development
        if (credentials?.email === process.env.DEMO_USER_EMAIL && credentials?.password === process.env.DEMO_USER_PASSWORD) {
          return {
            id: "1",
            name: "Demo User",
            email: process.env.DEMO_USER_EMAIL,
          };
        }
        // Test user for AWS Cognito testing
        if (credentials?.email === process.env.TEST_USER_EMAIL && credentials?.password === process.env.TEST_USER_PASSWORD) {
          return {
            id: "2",
            name: "Test User",
            email: process.env.TEST_USER_EMAIL,
          };
        }
        return null;
      }
    })
  ],
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/auth/signin",
  },
  debug: process.env.NODE_ENV === "development",
});

export { handler as GET, handler as POST };
