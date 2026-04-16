import { useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { X, Send, Save, Image as ImageIcon, ChevronDown } from 'lucide-react'
import { format } from 'date-fns'
import type { Report, ConversationMessage } from '../types'
import { riskColor, riskLabel, statusLabel } from '../types'

interface Props {
  report: Report
  onClose: (updated?: Report) => void
}

type Status = 'pending' | 'in_progress' | 'resolved'

const ANALYSIS_BASE_FIELDS = ['Defect Category', 'Risk Level', 'Severity', 'Recommended Action']

function parseAnalysisFields(raw: string): Record<string, string> {
  if (!raw) return {}
  try {
    const parsed = JSON.parse(raw) as Record<string, string>
    if (typeof parsed === 'object' && !Array.isArray(parsed)) return parsed
  } catch {  }

  const result: Record<string, string> = {}
  const lines = raw.split('\n')
  let current = ''
  let currentVal = ''

  for (const line of lines) {
    const colonIdx = line.indexOf(':')
    if (colonIdx > 0 && colonIdx < 40) {
      if (current) result[current] = currentVal.trim()
      current = line.slice(0, colonIdx).trim()
      currentVal = line.slice(colonIdx + 1).trim()
    } else if (current) {
      currentVal += '\n' + line
    }
  }
  if (current) result[current] = currentVal.trim()
  return result
}

function buildAnalysisText(fields: Record<string, string>): string {
  return Object.entries(fields)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n')
}

export function ReportDetailModal({ report, onClose }: Props) {
  const [title, setTitle] = useState(report.title ?? '')
  const [status, setStatus] = useState<Status>((report.status as Status) ?? 'pending')
  const [riskLevel, setRiskLevel] = useState<string>(report.risk_level ?? 'medium')
  const [riskScore, setRiskScore] = useState(report.risk_score ?? 50)
  const [analysisFields, setAnalysisFields] = useState<Record<string, string>>(
    parseAnalysisFields(report.ai_analysis ?? '')
  )
  const [conversation, setConversation] = useState<ConversationMessage[]>(
    report.conversation ?? []
  )
  const [newMessage, setNewMessage] = useState('')
  const [isSaving, setIsSaving] = useState(false)
  const [isSending, setIsSending] = useState(false)
  const [showPhoto, setShowPhoto] = useState(true)
  const [hasChanges, setHasChanges] = useState(false)
  const convoEndRef = useRef<HTMLDivElement>(null)

  const extraFields = Object.keys(analysisFields).filter(k => !ANALYSIS_BASE_FIELDS.includes(k))
  const allFields = [...ANALYSIS_BASE_FIELDS, ...extraFields]

  useEffect(() => {
    const channel = supabase
      .channel(`report-${report.id}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'reports', filter: `id=eq.${report.id}` },
        payload => {
          const updated = payload.new as Report
          setConversation(updated.conversation ?? [])
          setStatus((updated.status as Status) ?? 'pending')
        }
      )
      .subscribe()
    return () => { void supabase.removeChannel(channel) }
  }, [report.id])

  useEffect(() => {
    convoEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [conversation])

  const markChanged = () => setHasChanges(true)

  const handleSave = async () => {
    setIsSaving(true)
    try {
      const aiAnalysisText = buildAnalysisText(analysisFields)
      const { data, error } = await supabase
        .from('reports')
        .update({
          title,
          status,
          risk_level: riskLevel,
          risk_score: riskScore,
          ai_analysis: aiAnalysisText,
          updated_at: new Date().toISOString(),
        })
        .eq('id', report.id)
        .select()
        .single()
      if (error) throw error
      setHasChanges(false)
      onClose(data as Report)
    } catch (e) {
      alert(`儲存失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setIsSaving(false)
    }
  }

  const handleSendMessage = async () => {
    const text = newMessage.trim()
    if (!text) return
    setIsSending(true)
    try {
      const msg: ConversationMessage = {
        sender: 'company',
        text,
        timestamp: new Date().toISOString(),
      }
      const updated = [...conversation, msg]
      const { error } = await supabase
        .from('reports')
        .update({ conversation: updated, updated_at: new Date().toISOString() })
        .eq('id', report.id)
      if (error) throw error
      setConversation(updated)
      setNewMessage('')
    } catch (e) {
      alert(`發送失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setIsSending(false)
    }
  }

  const imageUrl = report.image_url ?? (report.image_base64 ? `data:image/jpeg;base64,${report.image_base64}` : null)

  const STATUS_OPTIONS: { value: Status; label: string }[] = [
    { value: 'pending',     label: '待處理' },
    { value: 'in_progress', label: '處理中' },
    { value: 'resolved',    label: '已解決' },
  ]

  const RISK_OPTIONS = [
    { value: 'high',   label: '高風險' },
    { value: 'medium', label: '中風險' },
    { value: 'low',    label: '低風險' },
  ]

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-5xl max-h-[90vh] flex flex-col mx-4">
        {}
        <div className="flex items-center gap-3 px-6 py-4 border-b border-app-border flex-shrink-0">
          <div className="flex-1 min-w-0">
            <input
              value={title}
              onChange={e => { setTitle(e.target.value); markChanged() }}
              className="text-lg font-bold w-full border-0 outline-none bg-transparent"
              placeholder="報告標題"
            />
          </div>
          <button
            onClick={() => onClose()}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors flex-shrink-0"
          >
            <X size={20} />
          </button>
        </div>

        {}
        <div className="flex-1 overflow-hidden flex">
          {}
          <div className="flex-1 overflow-y-auto p-6 border-r border-app-border">
            {}
            {imageUrl && (
              <div className="mb-5">
                <button
                  onClick={() => setShowPhoto(v => !v)}
                  className="flex items-center gap-2 text-sm font-semibold text-app-text-primary mb-2"
                >
                  <ImageIcon size={15} />
                  現場照片
                  <ChevronDown size={14} className={`transition-transform ${showPhoto ? '' : '-rotate-90'}`}/>
                </button>
                {showPhoto && (
                  <img
                    src={imageUrl}
                    alt="現場照片"
                    className="w-full max-h-52 object-contain rounded-xl border border-app-border bg-gray-50"
                  />
                )}
              </div>
            )}

            {}
            <div className="grid grid-cols-2 gap-3 mb-5">
              <div>
                <label className="block text-xs text-app-text-secondary mb-1">狀態</label>
                <div className="relative">
                  <select
                    value={status}
                    onChange={e => { setStatus(e.target.value as Status); markChanged() }}
                    className="w-full border border-app-border rounded-lg px-3 py-2 text-sm appearance-none bg-white pr-8 focus:outline-none focus:ring-2 focus:ring-primary/30"
                  >
                    {STATUS_OPTIONS.map(o => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-xs text-app-text-secondary mb-1">風險等級</label>
                <select
                  value={riskLevel}
                  onChange={e => { setRiskLevel(e.target.value); markChanged() }}
                  className="w-full border border-app-border rounded-lg px-3 py-2 text-sm appearance-none bg-white focus:outline-none focus:ring-2 focus:ring-primary/30"
                >
                  {RISK_OPTIONS.map(o => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs text-app-text-secondary mb-1">風險分數</label>
                <div className="flex items-center gap-2">
                  <input
                    type="range"
                    min={0}
                    max={100}
                    value={riskScore}
                    onChange={e => { setRiskScore(Number(e.target.value)); markChanged() }}
                    className="flex-1 accent-primary"
                  />
                  <span className="text-sm font-bold w-8 text-right" style={{ color: riskColor(riskLevel) }}>
                    {riskScore}
                  </span>
                </div>
              </div>
              <div>
                <label className="block text-xs text-app-text-secondary mb-1">目前風險等級</label>
                <span
                  className="px-3 py-1.5 rounded-full text-sm font-semibold inline-block"
                  style={{ backgroundColor: `${riskColor(riskLevel)}1a`, color: riskColor(riskLevel) }}
                >
                  {riskLabel(riskLevel)}
                </span>
              </div>
            </div>

            {}
            <h3 className="text-sm font-semibold text-app-text-primary mb-3">AI 分析內容</h3>
            <div className="flex flex-col gap-3">
              {allFields.map(field => (
                <div key={field}>
                  <label className="block text-xs text-app-text-secondary mb-1">{field}</label>
                  <textarea
                    value={analysisFields[field] ?? ''}
                    onChange={e => {
                      setAnalysisFields(prev => ({ ...prev, [field]: e.target.value }))
                      markChanged()
                    }}
                    rows={2}
                    className="w-full border border-app-border rounded-lg px-3 py-2 text-sm resize-y focus:outline-none focus:ring-2 focus:ring-primary/30"
                  />
                </div>
              ))}
            </div>

            {}
            {report.location && (
              <div className="mt-4">
                <label className="block text-xs text-app-text-secondary mb-1">位置</label>
                <p className="text-sm text-app-text-primary">{report.location}</p>
              </div>
            )}
          </div>

          {}
          <div className="w-80 flex-shrink-0 flex flex-col">
            <div className="px-4 py-3 border-b border-app-border flex-shrink-0">
              <h3 className="text-sm font-semibold text-app-text-primary">溝通記錄</h3>
              <p className="text-xs text-app-text-secondary mt-0.5">與現場工人的對話</p>
            </div>

            {}
            <div className="flex-1 overflow-y-auto p-4 flex flex-col gap-3">
              {conversation.length === 0 ? (
                <p className="text-xs text-app-text-secondary text-center mt-8">尚無訊息</p>
              ) : (
                conversation.map((msg, i) => {
                  const isCompany = msg.sender === 'company'
                  return (
                    <div key={i} className={`flex ${isCompany ? 'justify-end' : 'justify-start'}`}>
                      <div
                        className={`max-w-[85%] rounded-2xl px-3 py-2 text-sm ${
                          isCompany
                            ? 'bg-primary text-white rounded-tr-sm'
                            : 'bg-gray-100 text-app-text-primary rounded-tl-sm'
                        }`}
                      >
                        {msg.image && (
                          <img
                            src={msg.image.startsWith('data:') ? msg.image : `data:image/jpeg;base64,${msg.image}`}
                            alt="附圖"
                            className="w-full rounded-lg mb-1.5 max-h-32 object-cover"
                          />
                        )}
                        <p className="whitespace-pre-wrap break-words">{msg.text}</p>
                        <p className={`text-[10px] mt-1 ${isCompany ? 'text-white/60' : 'text-app-text-secondary'}`}>
                          {format(new Date(msg.timestamp), 'MM/dd HH:mm')}
                        </p>
                      </div>
                    </div>
                  )
                })
              )}
              <div ref={convoEndRef} />
            </div>

            {}
            <div className="p-3 border-t border-app-border flex-shrink-0">
              <div className="flex gap-2">
                <textarea
                  value={newMessage}
                  onChange={e => setNewMessage(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault()
                      void handleSendMessage()
                    }
                  }}
                  placeholder="輸入訊息…"
                  rows={2}
                  className="flex-1 border border-app-border rounded-xl px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-primary/30"
                />
                <button
                  onClick={() => void handleSendMessage()}
                  disabled={isSending || !newMessage.trim()}
                  className="flex items-center justify-center w-10 bg-primary text-white rounded-xl hover:bg-primary-dark transition-colors disabled:opacity-40 flex-shrink-0"
                >
                  <Send size={16} />
                </button>
              </div>
            </div>
          </div>
        </div>

        {}
        <div className="flex items-center justify-between px-6 py-4 border-t border-app-border flex-shrink-0">
          <div className="text-sm text-app-text-secondary">
            {statusLabel(status)} · {riskLabel(riskLevel)}
          </div>
          <div className="flex gap-3">
            <button
              onClick={() => onClose()}
              className="px-4 py-2 border border-app-border rounded-xl text-sm text-app-text-secondary hover:bg-gray-50 transition-colors"
            >
              取消
            </button>
            <button
              onClick={() => void handleSave()}
              disabled={!hasChanges || isSaving}
              className="flex items-center gap-2 px-5 py-2 bg-primary text-white rounded-xl text-sm font-semibold hover:bg-primary-dark transition-colors disabled:opacity-40"
            >
              <Save size={15} />
              {isSaving ? '儲存中…' : '儲存'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
