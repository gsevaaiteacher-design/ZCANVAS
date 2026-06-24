import React, { useState, useEffect } from 'react'
import Canvas from './components/Canvas'
import { supabase } from './lib/supabase'
import './App.css'

export default function App() {
  const [drawings, setDrawings] = useState([])
  const [currentDrawing, setCurrentDrawing] = useState(null)
  const [canvasData, setCanvasData] = useState(null)
  const [showSaveDialog, setShowSaveDialog] = useState(false)
  const [drawingName, setDrawingName] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchDrawings()
  }, [])

  async function fetchDrawings() {
    try {
      const { data, error } = await supabase
        .from('drawings')
        .select('*')
        .order('updated_at', { ascending: false })

      if (error) throw error
      setDrawings(data || [])
    } catch (err) {
      console.error('Failed to fetch drawings:', err)
    } finally {
      setLoading(false)
    }
  }

  async function handleSave() {
    if (!canvasData) return

    try {
      if (currentDrawing) {
        const { error } = await supabase
          .from('drawings')
          .update({
            canvas_data: canvasData,
            updated_at: new Date().toISOString()
          })
          .eq('id', currentDrawing.id)

        if (error) throw error
        setDrawings(prev => prev.map(d =>
          d.id === currentDrawing.id ? { ...d, canvas_data: canvasData, updated_at: new Date().toISOString() } : d
        ))
      } else if (drawingName.trim()) {
        const { data, error } = await supabase
          .from('drawings')
          .insert({
            name: drawingName.trim(),
            canvas_data: canvasData
          })
          .select()
          .single()

        if (error) throw error
        setCurrentDrawing(data)
        setDrawings(prev => [data, ...prev])
        setShowSaveDialog(false)
        setDrawingName('')
      }
    } catch (err) {
      console.error('Failed to save drawing:', err)
      alert('Failed to save drawing. Please try again.')
    }
  }

  async function handleNewDrawing() {
    setCurrentDrawing(null)
    setCanvasData(null)
    setDrawingName('')
  }

  async function handleLoadDrawing(drawing) {
    setCurrentDrawing(drawing)
    setCanvasData(drawing.canvas_data)
  }

  async function handleDeleteDrawing(id) {
    if (!confirm('Delete this drawing?')) return

    try {
      const { error } = await supabase
        .from('drawings')
        .delete()
        .eq('id', id)

      if (error) throw error
      setDrawings(prev => prev.filter(d => d.id !== id))
      if (currentDrawing?.id === id) {
        handleNewDrawing()
      }
    } catch (err) {
      console.error('Failed to delete drawing:', err)
    }
  }

  function formatDate(dateStr) {
    const date = new Date(dateStr)
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }

  return (
    <div className="app">
      <aside className="sidebar">
        <div className="sidebar-header">
          <h1>Canvas</h1>
          <button className="new-btn" onClick={handleNewDrawing}>
            <svg viewBox="0 0 24 24" fill="currentColor" width="18" height="18">
              <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
            </svg>
            New
          </button>
        </div>

        <div className="save-section">
          {currentDrawing ? (
            <div className="current-drawing">
              <span className="drawing-title">{currentDrawing.name}</span>
              <button className="save-btn" onClick={handleSave}>
                <svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16">
                  <path d="M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z"/>
                </svg>
                Save
              </button>
            </div>
          ) : (
            <button className="save-btn" onClick={() => setShowSaveDialog(true)} disabled={!canvasData}>
              <svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16">
                <path d="M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z"/>
              </svg>
              Save Drawing
            </button>
          )}
        </div>

        <div className="drawings-list">
          <h2>Saved Drawings</h2>
          {loading ? (
            <p className="loading">Loading...</p>
          ) : drawings.length === 0 ? (
            <p className="empty">No saved drawings yet</p>
          ) : (
            <ul>
              {drawings.map(drawing => (
                <li key={drawing.id} className={currentDrawing?.id === drawing.id ? 'active' : ''}>
                  <button className="drawing-item" onClick={() => handleLoadDrawing(drawing)}>
                    <img src={drawing.canvas_data} alt={drawing.name} className="thumbnail" />
                    <div className="drawing-info">
                      <span className="drawing-name">{drawing.name}</span>
                      <span className="drawing-date">{formatDate(drawing.updated_at)}</span>
                    </div>
                  </button>
                  <button className="delete-btn" onClick={() => handleDeleteDrawing(drawing.id)} title="Delete">
                    <svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16">
                      <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/>
                    </svg>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </aside>

      <main className="main-content">
        <Canvas
          key={currentDrawing?.id || 'new'}
          savedCanvas={canvasData}
          onCanvasChange={setCanvasData}
        />
      </main>

      {showSaveDialog && (
        <div className="dialog-overlay" onClick={() => setShowSaveDialog(false)}>
          <div className="dialog" onClick={e => e.stopPropagation()}>
            <h2>Save Drawing</h2>
            <input
              type="text"
              placeholder="Enter drawing name..."
              value={drawingName}
              onChange={e => setDrawingName(e.target.value)}
              autoFocus
            />
            <div className="dialog-actions">
              <button className="cancel-btn" onClick={() => setShowSaveDialog(false)}>Cancel</button>
              <button className="confirm-btn" onClick={handleSave} disabled={!drawingName.trim()}>
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
