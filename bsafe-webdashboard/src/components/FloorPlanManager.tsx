import { useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { RefreshCw, Upload, Trash2, Eye } from 'lucide-react'
import { format } from 'date-fns'
import type { FloorPlanSession, Pin } from '../types'
import { FloorPlanPreviewModal } from './FloorPlanPreviewModal'

function extractBuildingName(row: FloorPlanSession): string {
  const p = row.payload
  const explicit = p?.building_name ?? p?.buildingName
  if (explicit && explicit.trim()) return explicit.trim()

  const path = row.floor_plan_path ?? p?.floorPlanPath ?? p?.floor_plan_path
  if (path && path.startsWith('buildings/')) {
    const parts = path.split('/')
    if (parts.length >= 2 && parts[1]) return parts[1]
  }
  return '未分類'
}

function resolveImageUrl(row: FloorPlanSession, supabaseUrl: string): string | null {
  const p = row.payload
  const direct = p?.floor_plan_url ?? p?.floorPlanUrl
  if (direct && direct.trim()) {
    if (direct.startsWith('http')) return direct
    return `${supabaseUrl}/storage/v1/object/public/floor-plans/${direct}`
  }
  const path = row.floor_plan_path ?? p?.floorPlanPath ?? p?.floor_plan_path
  if (path && path.trim()) {
    if (path.startsWith('http')) return path
    return `${supabaseUrl}/storage/v1/object/public/floor-plans/${path}`
  }
  return null
}

function resolveBase64(row: FloorPlanSession): string | null {
  const p = row.payload
  return p?.floor_plan_base64 ?? p?.floorPlanBase64 ?? null
}

function extractPins(row: FloorPlanSession): Pin[] {
  const pins = row.payload?.pins
  if (!Array.isArray(pins)) return []
  return pins.map(p => ({
    id: String(p.id ?? ''),
    x: Number(p.x ?? 0),
    y: Number(p.y ?? 0),
    label: String(p.label ?? ''),
  }))
}

export function FloorPlanManager() {
  const [sessions, setSessions] = useState<FloorPlanSession[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedFolder, setSelectedFolder] = useState<string | null>(null)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [buildingName, setBuildingName] = useState('')
  const [floorNumber, setFloorNumber] = useState('')
  const [previewRow, setPreviewRow] = useState<FloorPlanSession | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const supabaseUrl = (import.meta as any).env.VITE_SUPABASE_URL as string

  const load = async (silent = false) => {
    if (!silent) { setLoading(true); setError(null) }
    try {
      const { data, error: err } = await supabase
        .from('inspection_sessions')
        .select('session_id, floor, floor_plan_path, payload, created_at')
        .order('created_at', { ascending: false })
        .limit(100)
      if (err) throw err
      const rows = (data ?? []) as FloorPlanSession[]
      setSessions(rows)

      const folders = new Set(rows.map(r => extractBuildingName(r)))
      setSelectedFolder(prev => (prev && !folders.has(prev) ? null : prev))
    } catch (e) {
      setError(`載入樓層圖失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { void load() }, [])

  const grouped = sessions.reduce<Record<string, FloorPlanSession[]>>((acc, row) => {
    const key = extractBuildingName(row)
    ;(acc[key] ??= []).push(row)
    return acc
  }, {})
  const sortedFolders = Object.keys(grouped).sort()

  const selectedRows = selectedFolder ? (grouped[selectedFolder] ?? []) : []

  const handleUpload = async () => {
    const name = buildingName.trim()
    const floorNum = parseInt(floorNumber.trim(), 10)
    if (!name) { alert('請先輸入建築名稱（folder）'); return }
    if (isNaN(floorNum)) { alert('請先輸入正確樓層（數字）'); return }

    fileInputRef.current?.click()
  }

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    e.target.value = ''

    const name = buildingName.trim()
    const floorNum = parseInt(floorNumber.trim(), 10)

    setUploading(true)
    try {
      const bytes = await file.arrayBuffer()
      const uint8 = new Uint8Array(bytes)

      const buildingFolder = name
        .toLowerCase()
        .replace(/[^a-z0-9\u4e00-\u9fff_-]+/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '') || 'default'

      const path = `buildings/${buildingFolder}/floor_${floorNum}_${Date.now()}.jpg`

      let publicUrl: string | null = null
      let floorPlanPath: string | null = null
      let floorPlanBase64: string | null = null

      try {
        const { error: storageErr } = await supabase.storage
          .from('floor-plans')
          .upload(path, uint8, { upsert: true, contentType: file.type || 'image/jpeg' })

        if (storageErr) throw storageErr
        const { data: urlData } = supabase.storage.from('floor-plans').getPublicUrl(path)
        publicUrl = urlData.publicUrl
        floorPlanPath = path
      } catch {

        const base64 = btoa(String.fromCharCode(...uint8))
        floorPlanBase64 = base64
        floorPlanPath = null
        publicUrl = null
        alert('Storage 無權限，已改為資料庫儲存樓層圖')
      }

      const sessionId = `web_${Date.now()}`
      const { error: dbErr } = await supabase.from('inspection_sessions').insert({
        session_id: sessionId,
        name: `${name} - F${floorNum}`,
        project_id: 'web-dashboard',
        floor: floorNum,
        floor_plan_path: floorPlanPath,
        status: 'active',
        payload: {
          id: sessionId,
          name: `${name} - F${floorNum}`,
          projectId: 'web-dashboard',
          building_name: name,
          building_folder: buildingFolder,
          floor: floorNum,
          floor_plan_url: publicUrl,
          floorPlanPath: floorPlanPath,
          floor_plan_base64: floorPlanBase64,
          pins: [],
        },
      })
      if (dbErr) throw dbErr

      setFloorNumber('')
      await load(true)
    } catch (e) {
      alert(`上傳失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setUploading(false)
    }
  }

  const handleDelete = async (row: FloorPlanSession) => {
    if (!window.confirm(`確認刪除此樓層圖？`)) return
    setDeletingId(row.session_id)
    try {
      const path = row.floor_plan_path ?? row.payload?.floorPlanPath
      if (path) {
        try { await supabase.storage.from('floor-plans').remove([path]) } catch {  }
      }
      const { error: err } = await supabase
        .from('inspection_sessions')
        .delete()
        .eq('session_id', row.session_id)
      if (err) throw err
      await load(true)
    } catch (e) {
      alert(`刪除失敗: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      setDeletingId(null)
    }
  }

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {}
      <div className="bg-white px-8 py-5 flex items-center gap-4 flex-shrink-0 border-b border-app-border">
        <div>
          <h1 className="text-2xl font-bold text-app-text-primary">樓層圖管理</h1>
          <p className="text-app-text-secondary text-sm mt-1">上傳樓層圖供手機端選擇、加 pin 並上報</p>
        </div>
        <button
          onClick={() => load()}
          className="ml-auto flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition-colors"
        >
          <RefreshCw size={15} />
          刷新
        </button>
      </div>

      {}
      <div className="px-8 pt-5 pb-3 flex items-end gap-3 flex-shrink-0">
        <div>
          <label className="block text-xs text-app-text-secondary mb-1">建築名稱 / Folder</label>
          <input
            value={buildingName}
            onChange={e => setBuildingName(e.target.value)}
            placeholder="例如: Building_A"
            className="border border-app-border rounded-xl px-3 py-2 text-sm w-52 focus:outline-none focus:ring-2 focus:ring-primary/30"
          />
        </div>
        <div>
          <label className="block text-xs text-app-text-secondary mb-1">樓層</label>
          <input
            value={floorNumber}
            onChange={e => setFloorNumber(e.target.value)}
            placeholder="例如 3"
            type="number"
            className="border border-app-border rounded-xl px-3 py-2 text-sm w-32 focus:outline-none focus:ring-2 focus:ring-primary/30"
          />
        </div>
        <button
          onClick={() => void handleUpload()}
          disabled={uploading}
          className="flex items-center gap-2 px-5 py-2 bg-primary text-white rounded-xl text-sm font-semibold hover:bg-primary-dark transition-colors disabled:opacity-50"
        >
          <Upload size={15} />
          {uploading ? '上傳中…' : '上傳樓層圖'}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={e => void handleFileChange(e)}
        />
      </div>

      {}
      <div className="flex-1 overflow-y-auto px-8 pb-8">
        {loading ? (
          <div className="flex justify-center items-center h-48">
            <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : error ? (
          <p className="text-risk-high text-sm">{error}</p>
        ) : sessions.length === 0 ? (
          <div className="flex justify-center items-center h-48 text-app-text-secondary text-sm">
            尚未有樓層圖
          </div>
        ) : (
          <>
            {}
            <div className="flex flex-wrap gap-2 mb-4">
              {sortedFolders.map(folder => (
                <button
                  key={folder}
                  onClick={() => setSelectedFolder(folder)}
                  className={[
                    'px-3 py-1.5 rounded-full text-sm font-medium border transition-colors',
                    selectedFolder === folder
                      ? 'bg-primary/10 text-primary border-primary/40'
                      : 'bg-white text-app-text-secondary border-app-border hover:bg-gray-50',
                  ].join(' ')}
                >
                  {folder} ({(grouped[folder] ?? []).length})
                </button>
              ))}
            </div>

            {}
            {selectedFolder === null ? (
              <p className="text-app-text-secondary text-sm">請先點選一個 folder 查看對應樓層圖</p>
            ) : selectedRows.length === 0 ? (
              <p className="text-app-text-secondary text-sm">此 folder 暫無樓層圖</p>
            ) : (
              <div className="flex flex-col gap-3">
                {selectedRows.map(row => {
                  const imgUrl = resolveImageUrl(row, supabaseUrl)
                  const imgB64 = resolveBase64(row)
                  const imgSrc = imgUrl ?? (imgB64 ? `data:image/jpeg;base64,${imgB64}` : null)
                  const pins = extractPins(row)
                  const buildingLabel = extractBuildingName(row)
                  const floor = row.floor ?? row.payload?.floor
                  const createdAt = row.created_at
                    ? format(new Date(row.created_at), 'yyyy/MM/dd HH:mm')
                    : '-'
                  const isDeleting = deletingId === row.session_id

                  return (
                    <div
                      key={row.session_id}
                      className="bg-white rounded-xl border border-app-border p-4 flex items-start gap-4"
                    >
                      {}
                      <button
                        onClick={() => setPreviewRow(row)}
                        className="flex-shrink-0 w-36 h-24 rounded-lg overflow-hidden bg-gray-100 border border-app-border hover:opacity-80 transition-opacity"
                      >
                        {imgSrc ? (
                          <img src={imgSrc} alt="樓層圖" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-app-text-secondary text-xs">
                            無圖片
                          </div>
                        )}
                      </button>

                      {}
                      <div className="flex-1 min-w-0">
                        <p className="font-bold text-base">{buildingLabel} - {floor} F</p>
                        <p className="text-xs text-app-text-secondary mt-1">Session: {row.session_id}</p>
                        <p className="text-xs text-app-text-secondary">Pins: {pins.length} · 上傳: {createdAt}</p>
                      </div>

                      {}
                      <div className="flex-shrink-0 flex items-center gap-1">
                        <button
                          onClick={() => setPreviewRow(row)}
                          className="p-2 text-primary hover:bg-primary/10 rounded-lg transition-colors"
                          title="預覽"
                        >
                          <Eye size={18} />
                        </button>
                        <button
                          onClick={() => void handleDelete(row)}
                          disabled={isDeleting}
                          className="p-2 text-red-400 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-40"
                          title="刪除"
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </>
        )}
      </div>

      {}
      {previewRow && (
        <FloorPlanPreviewModal
          imageUrl={resolveImageUrl(previewRow, supabaseUrl)}
          imageBase64={resolveBase64(previewRow)}
          pins={extractPins(previewRow)}
          title={`${extractBuildingName(previewRow)} - ${previewRow.floor ?? previewRow.payload?.floor} F`}
          onClose={() => setPreviewRow(null)}
        />
      )}
    </div>
  )
}
