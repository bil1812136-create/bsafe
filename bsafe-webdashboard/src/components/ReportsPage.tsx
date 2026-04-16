import { useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import {
  FileText, AlertTriangle, Info, CheckCircle,
  RefreshCw, Eye, Trash2, Inbox
} from 'lucide-react'
import { format } from 'date-fns'
import type { Report, RiskLevel } from '../types'
import {
  riskColor, riskBgClass, riskLabel,
  statusLabel, statusBadgeClass, categoryLabel
} from '../types'
import { ReportDetailModal } from './ReportDetailModal'

export function ReportsPage() {
  const [reports, setReports] = useState<Report[]>([])
  const [filter, setFilter] = useState<'all' | RiskLevel>('all')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedReport, setSelectedReport] = useState<Report | null>(null)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const loadReports = async (silent = false) => {
    if (!silent) { setLoading(true); setError(null) }
    try {
      let query = supabase.from('reports').select('*')
      if (filter !== 'all') query = query.eq('risk_level', filter)
      const { data, error: err } = await query.order('created_at', { ascending: false })
      if (err) throw err
      setReports((data ?? []) as Report[])
    } catch (e) {
      setError(`載入失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { void loadReports() }, [filter])

  useEffect(() => {
    intervalRef.current = setInterval(() => { void loadReports(true) }, 15_000)
    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [filter])

  const handleDelete = async (report: Report) => {
    if (!window.confirm(`確認刪除報告「${report.title}」？`)) return
    setDeletingId(report.id)
    try {
      const { error: err } = await supabase.from('reports').delete().eq('id', report.id)
      if (err) throw err
      setReports(prev => prev.filter(r => r.id !== report.id))
    } catch (e) {
      alert(`刪除失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setDeletingId(null)
    }
  }

  const handleDetailClose = (updated?: Report) => {
    setSelectedReport(null)
    if (updated) {
      setReports(prev => prev.map(r => r.id === updated.id ? updated : r))
    }
  }

  const total  = reports.length
  const high   = reports.filter(r => r.risk_level === 'high').length
  const medium = reports.filter(r => r.risk_level === 'medium').length
  const low    = reports.filter(r => r.risk_level === 'low').length

  const statsCards = [
    { label: '全部報告', value: total,  color: '#1E40AF', icon: FileText,      filterVal: 'all' as const },
    { label: '高風險',   value: high,   color: '#DC2626', icon: AlertTriangle,  filterVal: 'high' as const },
    { label: '中風險',   value: medium, color: '#F59E0B', icon: Info,           filterVal: 'medium' as const },
    { label: '低風險',   value: low,    color: '#16A34A', icon: CheckCircle,    filterVal: 'low' as const },
  ]

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {}
      <div className="bg-white px-8 py-5 flex items-center gap-4 flex-shrink-0 border-b border-app-border">
        <div>
          <h1 className="text-2xl font-bold text-app-text-primary">報告總覽</h1>
          <p className="text-app-text-secondary text-sm mt-1">手機端上報的 AI 分析報告會自動同步到此頁面</p>
        </div>
        <div className="ml-auto flex items-center gap-3">
          <button
            onClick={() => loadReports()}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition-colors"
          >
            <RefreshCw size={15} />
            刷新
          </button>
          <span className="text-app-text-secondary text-sm">共 {total} 筆報告</span>
        </div>
      </div>

      {}
      <div className="px-8 py-4 flex gap-4 flex-shrink-0">
        {statsCards.map(card => {
          const Icon = card.icon
          const active = filter === card.filterVal
          return (
            <button
              key={card.label}
              onClick={() => setFilter(card.filterVal)}
              className="flex-1 flex items-center gap-3 p-5 rounded-2xl bg-white transition-all text-left"
              style={{
                border: active ? `2px solid ${card.color}` : '2px solid transparent',
                backgroundColor: active ? `${card.color}14` : 'white',
                boxShadow: active ? '0 2px 10px rgba(0,0,0,0.08)' : '0 2px 10px rgba(0,0,0,0.04)',
              }}
            >
              <div className="p-2.5 rounded-xl flex-shrink-0" style={{ backgroundColor: `${card.color}1a` }}>
                <Icon size={22} style={{ color: card.color }} />
              </div>
              <div className="min-w-0">
                <div className="text-3xl font-bold leading-tight" style={{ color: card.color }}>
                  {card.value}
                </div>
                <div className="text-app-text-secondary text-[13px] truncate">{card.label}</div>
              </div>
            </button>
          )
        })}
      </div>

      {}
      <div className="px-8 pb-3 flex items-center gap-2 flex-shrink-0">
        <span className="text-sm font-semibold text-app-text-primary mr-1">風險等級:</span>
        {(['all', 'high', 'medium', 'low'] as const).map(v => {
          const labels: Record<string, string> = { all: '全部', high: '高風險', medium: '中風險', low: '低風險' }
          const active = filter === v
          return (
            <button
              key={v}
              onClick={() => setFilter(v)}
              className={[
                'px-3 py-1.5 rounded-full text-sm font-medium border transition-colors',
                active
                  ? 'bg-primary/10 text-primary border-primary/30'
                  : 'bg-white text-app-text-secondary border-app-border hover:bg-gray-50',
              ].join(' ')}
            >
              {labels[v]}
            </button>
          )
        })}
      </div>

      {}
      <div className="flex-1 overflow-auto px-8 pb-8">
        {loading ? (
          <div className="flex justify-center items-center h-48">
            <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center h-48 gap-4">
            <AlertTriangle size={48} className="text-risk-high" />
            <p className="text-risk-high">{error}</p>
            <button onClick={() => loadReports()} className="px-5 py-2 bg-primary text-white rounded-xl text-sm hover:bg-primary-dark">
              重試
            </button>
          </div>
        ) : reports.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-48 gap-3 text-app-text-secondary">
            <Inbox size={56} />
            <p className="text-lg">尚無報告</p>
            <p className="text-sm">手機端上報後會自動同步到此頁面（每 15 秒刷新一次）</p>
          </div>
        ) : (
          <div className="bg-white rounded-2xl shadow-card overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm border-collapse">
                <thead>
                  <tr className="border-b border-app-border text-left" style={{ backgroundColor: '#1E40AF0d' }}>
                    {['#', '標題', '類別', '風險分數', '狀態', '日期', '操作'].map(h => (
                      <th key={h} className="px-4 py-3 font-semibold text-app-text-primary whitespace-nowrap">
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {reports.map((report, idx) => (
                    <tr
                      key={report.id}
                      className="border-b border-app-border last:border-0 hover:bg-gray-50 transition-colors"
                    >
                      <td className="px-4 py-3 text-app-text-secondary">{idx + 1}</td>
                      <td className="px-4 py-3 max-w-[200px]">
                        <span className="font-semibold truncate block">{report.title || '無標題'}</span>
                      </td>
                      <td className="px-4 py-3 text-app-text-secondary whitespace-nowrap">
                        {categoryLabel(report.category)}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className="font-bold" style={{ color: riskColor(report.risk_level) }}>
                          {report.risk_score}
                        </span>
                        <span className={`ml-2 px-2 py-0.5 rounded-full text-xs font-medium ${riskBgClass(report.risk_level)}`}>
                          {riskLabel(report.risk_level)}
                        </span>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${statusBadgeClass(report.status)}`}>
                          {statusLabel(report.status)}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-app-text-secondary whitespace-nowrap text-xs">
                        {format(new Date(report.created_at), 'yyyy/MM/dd HH:mm')}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <button
                          onClick={() => setSelectedReport(report)}
                          className="p-1.5 text-primary hover:bg-primary/10 rounded-lg transition-colors mr-1"
                          title="查看 / 編輯"
                        >
                          <Eye size={18} />
                        </button>
                        <button
                          onClick={() => handleDelete(report)}
                          disabled={deletingId === report.id}
                          className="p-1.5 text-red-400 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-40"
                          title="刪除"
                        >
                          <Trash2 size={18} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>

      {}
      {selectedReport && (
        <ReportDetailModal report={selectedReport} onClose={handleDetailClose} />
      )}
    </div>
  )
}
