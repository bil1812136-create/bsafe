import { useState } from 'react'
import { Sidebar } from './components/Sidebar'
import { ReportsPage } from './components/ReportsPage'
import { FloorPlanManager } from './components/FloorPlanManager'
import type { ActiveSection } from './types'

function App() {
  const [activeSection, setActiveSection] = useState<ActiveSection>('reports')

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar
        activeSection={activeSection}
        onSectionChange={setActiveSection}
        connected={true}
      />
      <main className="flex-1 overflow-hidden bg-app-bg">
        {activeSection === 'reports' ? (
          <ReportsPage />
        ) : (
          <FloorPlanManager />
        )}
      </main>
    </div>
  )
}

export default App
