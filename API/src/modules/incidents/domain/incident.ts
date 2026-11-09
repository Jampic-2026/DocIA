export type Incident = {
  id: string;
  module: string;
  incidentType: string;
  severity: string;
  description: string;
  status: string;
  resolution: string | null;
  resolvedAt: Date | null;
  createdAt: Date;
};
