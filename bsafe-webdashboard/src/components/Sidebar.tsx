import { LayoutDashboard, BarChart2, Map, Settings, ShieldCheck } from 'lucide-react'
import type { ActiveSection } from '../types'

interface SidebarProps {
  activeSection: ActiveSection
  onSectionChange: (section: ActiveSection) => void
  connected: boolean
}

const navItems = [
  { id: 'reports' as ActiveSection,     icon: LayoutDashboard, label: '報告總覽' },
  { id: null,                            icon: BarChart2,       label: '統計分析' },
  { id: 'floor_plans' as ActiveSection, icon: Map,             label: '樓層圖管理' },
  { id: null,                            icon: Settings,        label: '設定' },
]

export function Sidebar({ activeSection, onSectionChange, connected }: SidebarProps) {
  return (
    <aside className="w-60 flex-shrink-0 flex flex-col" style={{ backgroundColor: '#1E3A8A', minHeight: '100vh' }}>
      {}
      <div className="pt-8 px-6 pb-2">
        <div className="flex items-center gap-3">
          <ShieldCheck size={32} className="text-white" />
          <span className="text-white text-2xl font-bold tracking-wide">B-SAFE</span>
        </div>
        <p className="text-white/70 text-[13px] mt-1">公司管理後台</p>
      </div>

      {}
      <nav className="mt-8 flex flex-col gap-1 px-3">
        {navItems.map(({ id, icon: Icon, label }) => {
          const active = id !== null && activeSection === id
          const clickable = id !== null

          return (
            <button
              key={label}
              onClick={() => clickable && onSectionChange(id!)}
              disabled={!clickable}
              className={[
                'flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm transition-colors w-full text-left',
                active
                  ? 'bg-white/15 text-white font-semibold'
                  : clickable
                  ? 'text-white/60 hover:bg-white/10 hover:text-white/80 cursor-pointer'
                  : 'text-white/40 cursor-not-allowed',
              ].join(' ')}
            >
              <Icon size={20} />
              <span>{label}</span>
            </button>
          )
        })}
      </nav>

      {}
      <div className="flex-1" />

      {}
      <div className="m-5">
        <div className="rounded-xl p-3" style={{ backgroundColor: 'rgba(34,197,94,0.15)' }}>
          <div className="flex items-center gap-2">
            <div className={`w-2 h-2 rounded-full flex-shrink-0 ${connected ? 'bg-green-400' : 'bg-red-400'}`} />
            <span className="text-white/70 text-xs">
              {connected ? 'Supabase 已連接' : 'Supabase 未連接'}
            </span>
          </div>
        </div>
      </div>
    </aside>
  )
}
