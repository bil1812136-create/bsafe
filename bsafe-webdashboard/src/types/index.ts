export type RiskLevel = 'high' | 'medium' | 'low'
export type ReportStatus = 'pending' | 'in_progress' | 'resolved'

export interface ConversationMessage {
  sender: 'company' | 'worker'
  text: string
  timestamp: string
  image?: string
}

export interface Report {
  id: number
  local_id?: number
  title: string
  description: string
  category: string
  severity: string
  risk_level: RiskLevel
  risk_score: number
  is_urgent: boolean
  status: ReportStatus
  image_url?: string
  image_base64?: string
  location?: string
  latitude?: number
  longitude?: number
  ai_analysis?: string
  company_notes?: string
  worker_response?: string
  worker_response_image?: string
  conversation?: ConversationMessage[]
  has_unread_company?: boolean
  created_at: string
  updated_at: string
}

export interface FloorPlanPayload {
  id: string
  name: string
  projectId?: string
  building_name?: string
  buildingName?: string
  building_folder?: string
  floor?: number
  floor_plan_url?: string
  floorPlanUrl?: string
  floorPlanPath?: string
  floor_plan_path?: string
  floor_plan_base64?: string
  floorPlanBase64?: string
  pins?: Pin[]
}

export interface FloorPlanSession {
  session_id: string
  name: string
  floor?: number
  floor_plan_path?: string
  payload: FloorPlanPayload
  created_at: string
}

export interface Pin {
  id?: string
  x: number
  y: number
  label?: string
}

export type ActiveSection = 'reports' | 'floor_plans'

export function riskColor(level: string): string {
  switch (level.toLowerCase()) {
    case 'high':   return '#DC2626'
    case 'medium': return '#F59E0B'
    case 'low':    return '#16A34A'
    default:       return '#6B7280'
  }
}

export function riskBgClass(level: string): string {
  switch (level.toLowerCase()) {
    case 'high':   return 'bg-red-100 text-red-700'
    case 'medium': return 'bg-amber-100 text-amber-700'
    case 'low':    return 'bg-green-100 text-green-700'
    default:       return 'bg-gray-100 text-gray-600'
  }
}

export function riskLabel(level: string): string {
  switch (level.toLowerCase()) {
    case 'high':   return '高風險'
    case 'medium': return '中風險'
    case 'low':    return '低風險'
    default:       return '未評估'
  }
}

export function statusLabel(status: string): string {
  switch (status) {
    case 'resolved':   return '已解決'
    case 'in_progress': return '處理中'
    default:           return '待處理'
  }
}

export function statusBadgeClass(status: string): string {
  switch (status) {
    case 'resolved':    return 'bg-green-100 text-green-700'
    case 'in_progress': return 'bg-orange-100 text-orange-700'
    default:            return 'bg-gray-100 text-gray-600'
  }
}

export function categoryLabel(category: string): string {
  const map: Record<string, string> = {
    structural: '結構',
    electrical: '電氣',
    fire_safety: '消防',
    environmental: '環境',
    equipment: '設備',
    other: '其他',
  }
  return map[category] ?? category
}
