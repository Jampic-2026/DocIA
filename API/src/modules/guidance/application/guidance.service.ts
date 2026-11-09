import { BadRequestException, Inject, Injectable } from "@nestjs/common";
import { RequestUser } from "../../../common/types/request-user";
import { ConsentsService } from "../../consents/application/consents.service";
import {
  MEET_PROVIDER,
  MeetProvider,
} from "../../integrations/domain/ports/meet-provider";
import {
  GUIDANCE_REPOSITORY,
  GuidanceRepository,
} from "../domain/guidance.repository";
import {
  evaluateRisk,
  isRiskPolicy,
  RiskEvaluation,
} from "../domain/risk-policy";
@Injectable()
export class GuidanceService {
  constructor(
    @Inject(GUIDANCE_REPOSITORY)
    private readonly repository: GuidanceRepository,
    @Inject(MEET_PROVIDER) private readonly meet: MeetProvider,
    private readonly consents: ConsentsService,
  ) {}
  async evaluate(
    user: RequestUser,
    patientId: string,
    text: string,
    useContext: boolean,
  ) {
    const configuration = await this.repository.policy(user);
    const contextUsed = useContext && configuration.enabled;
    const context = contextUsed
      ? await this.repository.context(user, patientId)
      : "";
    return {
      evaluation: evaluateRisk(
        configuration.policy,
        configuration.enabled,
        text,
        context,
      ),
      revision: configuration.revision,
      contextUsed,
    };
  }
  saveAssessment(
    user: RequestUser,
    conversationId: string,
    evaluation: RiskEvaluation,
    useContext: boolean,
    revision: number,
  ) {
    return this.repository.saveAssessment(
      user,
      conversationId,
      evaluation,
      useContext,
      revision,
    );
  }
  policy(user: RequestUser) {
    return this.repository.policy(user);
  }
  savePolicy(user: RequestUser, value: unknown) {
    if (!isRiskPolicy(value))
      throw new BadRequestException(
        "Política no válida: revisa códigos, términos, acciones y preguntas.",
      );
    return this.repository.savePolicy(user, value);
  }
  approvePolicy(user: RequestUser, revision: number, reference: string) {
    return this.repository.approvePolicy(user, revision, reference);
  }
  decision(
    user: RequestUser,
    id: string,
    decision: string,
    relatedId?: string,
  ) {
    return this.repository.decision(user, id, decision, relatedId);
  }
  calls(user: RequestUser) {
    return this.repository.calls(user);
  }
  requestCall(
    user: RequestUser,
    reason: string,
    assessmentId?: string,
    emergencyId?: string,
  ) {
    return this.repository.requestCall(user, reason, assessmentId, emergencyId);
  }
  staff(user: RequestUser) {
    return this.repository.staff(user);
  }
  transitionCall(
    user: RequestUser,
    id: string,
    action: string,
    professionalId?: string,
    notes?: string,
  ) {
    return this.repository.transitionCall(
      user,
      id,
      action,
      professionalId,
      notes,
      this.meet,
    );
  }
  async joinCall(user: RequestUser, id: string) {
    if (user.roles.includes("patient"))
      await this.consents.assertAccepted(user, "telemedicine");
    return this.repository.joinCall(user, id, this.meet);
  }
}
