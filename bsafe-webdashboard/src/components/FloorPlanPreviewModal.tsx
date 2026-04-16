import { useRef, useState } from 'react'
import { X, ZoomIn, ZoomOut } from 'lucide-react'
import type { Pin } from '../types'

interface Props {
  imageUrl: string | null
  imageBase64: string | null
  pins: Pin[]
  title: string
  onClose: () => void
}

export function FloorPlanPreviewModal({ imageUrl, imageBase64, pins, title, onClose }: Props) {
  const imgSrc = imageUrl ?? (imageBase64 ? `data:image/jpeg;base64,${imageBase64}` : null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [zoom, setZoom] = useState(1)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl mx-4 flex flex-col" style={{ maxHeight: '85vh' }}>
        {}
        <div className="flex items-center px-5 py-4 border-b border-app-border flex-shrink-0">
          <span className="font-bold text-lg flex-1 truncate">{title} — 樓層圖預覽與 Pin</span>
          <span className="text-sm text-app-text-secondary mr-4">Pins: {pins.length}</span>
          <div className="flex items-center gap-1 mr-3">
            <button
              onClick={() => setZoom(z => Math.max(0.5, z - 0.25))}
              className="p-1.5 hover:bg-gray-100 rounded-lg"
            >
              <ZoomOut size={16} />
            </button>
            <span className="text-xs w-10 text-center">{Math.round(zoom * 100)}%</span>
            <button
              onClick={() => setZoom(z => Math.min(3, z + 0.25))}
              className="p-1.5 hover:bg-gray-100 rounded-lg"
            >
              <ZoomIn size={16} />
            </button>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg">
            <X size={20} />
          </button>
        </div>

        {}
        <div className="flex-1 overflow-auto bg-gray-100 p-4">
          <div
            ref={containerRef}
            className="relative inline-block"
            style={{ transform: `scale(${zoom})`, transformOrigin: 'top left' }}
          >
            {imgSrc ? (
              <img
                src={imgSrc}
                alt="樓層圖"
                className="block max-w-full rounded-lg"
                style={{ maxHeight: '60vh' }}
                draggable={false}
              />
            ) : (
              <div className="w-96 h-64 flex items-center justify-center text-app-text-secondary bg-gray-200 rounded-lg">
                無圖片
              </div>
            )}

            {}
            {imgSrc && pins.map((pin, i) => (
              <div
                key={pin.id ?? i}
                title={`Pin ${pin.id ?? i + 1} (${pin.x.toFixed(1)}, ${pin.y.toFixed(1)})`}
                className="absolute"
                style={{
                  left: `calc(${pin.x}% - 9px)`,

                  top: `calc(${100 - pin.y}% - 9px)`,
                  pointerEvents: 'none',
                }}
              >
                <div className="w-[18px] h-[18px] rounded-full bg-red-500 border-2 border-white shadow-md" />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
