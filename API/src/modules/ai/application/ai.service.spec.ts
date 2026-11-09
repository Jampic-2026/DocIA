import { PostgresAiRepository } from "../infrastructure/persistence/postgres-ai.repository";
import { AiService } from "./ai.service";

const user = {
  id: "00000000-0000-4000-8000-000000000001",
  email: "admin@docia.test",
  sessionId: "session",
  roleCode: "admin",
  roles: ["admin"],
  permissions: ["ai.manage"],
};

describe("AiService voice maintenance", () => {
  it("closes expired voice sessions and charges the configured max minutes", async () => {
    const queries: Array<{ sql: string; params?: unknown[] }> = [];
    const client = {
      query: jest.fn(async (sql: string, params?: unknown[]) => {
        queries.push({ sql, params });
        if (
          sql.includes("FROM ai_voice_sessions") &&
          sql.includes("SKIP LOCKED")
        ) {
          return {
            rows: [
              {
                id: "10000000-0000-4000-8000-000000000001",
                user_id: "20000000-0000-4000-8000-000000000001",
                patient_id: "30000000-0000-4000-8000-000000000001",
                started_at: new Date(),
                max_billable_minutes: 4,
              },
            ],
          };
        }
        if (sql.includes("FROM coin_wallets") && sql.includes("FOR UPDATE")) {
          return {
            rows: [
              {
                id: "40000000-0000-4000-8000-000000000001",
                available_balance: "10",
                reserved_balance: "0",
              },
            ],
          };
        }
        if (sql.includes("FROM coin_lots")) {
          return {
            rows: [
              {
                id: "50000000-0000-4000-8000-000000000001",
                remaining_amount: "10",
              },
            ],
          };
        }
        if (sql.includes("INSERT INTO coin_transactions")) {
          return { rows: [{ id: "60000000-0000-4000-8000-000000000001" }] };
        }
        return { rows: [] };
      }),
    };
    const database = {
      transactionAsUser: jest.fn(
        async (_user: unknown, work: (client: unknown) => Promise<unknown>) =>
          work(client),
      ),
    };
    const service = new AiService(
      new PostgresAiRepository(database as never, { get: jest.fn() } as never),
      { get: jest.fn() } as never,
      { assertAccepted: jest.fn() } as never,
      { reply: jest.fn() } as never,
      {} as never,
    );

    await expect(service.processVoiceSessionMaintenance(user)).resolves.toEqual(
      {
        closed: 1,
      },
    );
    expect(
      queries.some(
        (query) =>
          query.sql.includes(
            "UPDATE ai_voice_sessions SET status='completed'",
          ) && query.params?.[1] === 4,
      ),
    ).toBe(true);
    expect(
      queries.some(
        (query) =>
          query.sql.includes("INSERT INTO coin_transactions") &&
          query.params?.[1] === -4,
      ),
    ).toBe(true);
  });
});

describe("AiService orientation integration", () => {
  function setup() {
    const repository = {
      prepareChatMessage: jest
        .fn()
        .mockResolvedValue({
          patientId: "synthetic-patient",
          conversationId: "synthetic-conversation",
          history: [{ role: "user", content: "synthetic input" }],
        }),
      saveChatResponse: jest.fn(),
      chatBalance: jest.fn().mockResolvedValue(8),
      refundChatCharge: jest.fn(),
      prepareVoiceSession: jest.fn(),
    };
    const consents = { assertAccepted: jest.fn() },
      provider = {
        reply: jest.fn().mockResolvedValue("Synthetic orientation"),
      };
    const guidance = {
      evaluate: jest
        .fn()
        .mockResolvedValue({
          evaluation: {
            riskLevel: "undetermined",
            recommendedAction: null,
            classificationStatus: "disabled",
            questions: [],
            matchedRules: [],
          },
          revision: 1,
          contextUsed: false,
        }),
      saveAssessment: jest.fn().mockResolvedValue("synthetic-assessment"),
    };
    return {
      repository,
      consents,
      provider,
      guidance,
      service: new AiService(
        repository as never,
        { get: jest.fn() } as never,
        consents as never,
        provider as never,
        guidance as never,
      ),
    };
  }
  it("preserves preventive alerts and actionable assessment identity without calling the text provider", async () => {
    const setupValue = setup();
    const reply = await setupValue.service.send(user, {
      message: "no puedo respirar",
    });
    expect(reply).toEqual(
      expect.objectContaining({
        riskLevel: "red",
        recommendedAction: "emergency",
        classificationStatus: "preventive_alert",
        assessmentId: "synthetic-assessment",
      }),
    );
    expect(setupValue.provider.reply).not.toHaveBeenCalled();
    expect(setupValue.repository.saveChatResponse).toHaveBeenCalled();
  });
  it("returns the recorded decision context and refunds charges when orientation persistence fails", async () => {
    const setupValue = setup();
    setupValue.guidance.saveAssessment.mockRejectedValue(
      new Error("database unavailable"),
    );
    await expect(
      setupValue.service.send(user, { message: "synthetic ordinary input" }),
    ).rejects.toThrow("database unavailable");
    expect(setupValue.repository.refundChatCharge).toHaveBeenCalledTimes(1);
    expect(setupValue.repository.saveChatResponse).not.toHaveBeenCalled();
  });
  it("prevents new unattended legacy voice sessions without debiting coins", async () => {
    const setupValue = setup();
    await expect(
      setupValue.service.startVoiceSession(user, {}),
    ).rejects.toThrow("Solicita orientación humana");
    expect(setupValue.repository.prepareVoiceSession).not.toHaveBeenCalled();
  });
});
