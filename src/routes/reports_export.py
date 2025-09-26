# ARQUIVO CORRIGIDO E SEGURO: src/routes/reports_export.py (COM DELEGAÇÃO HÍBRIDA)

from flask import Blueprint, request, jsonify, make_response
from datetime import datetime
import os
import base64

# --- Importações Condicionais ---
# Tenta importar as bibliotecas pesadas. Se falhar, não quebra o programa.
try:
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    import io
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False

# --- Importações Leves (Sempre Disponíveis) ---
from auth import verify_token
from models.transaction_mongo import Transaction
from models.category_mongo import Category
from src.services.hybrid_processor import HybridProcessor # Nosso "interruptor"

reports_export_bp = Blueprint('reports_export', __name__)

@reports_export_bp.route('/api/reports/export-pdf', methods=['GET'])
@verify_token
def export_transactions_pdf(current_user_uid, current_user_data):
    """
    Exporta transações para PDF.
    Usa o worker na nuvem se USE_HF_WORKER=true.
    Usa a lógica local se USE_HF_WORKER=false (produção).
    """
    use_hf_worker = os.getenv('USE_HF_WORKER', 'false').lower() == 'true'

    try:
        context = request.args.get('context', 'business')
        
        # 1. Coletar os dados localmente (operação leve, comum a ambos os modos)
        filters = {'user_id': current_user_uid, 'context': context}
        transactions = Transaction.find_all(filters)
        
        if not transactions:
            return jsonify({'error': 'Nenhuma transação encontrada'}), 404
        
        category_filters = {'user_id': current_user_uid, 'context': context}
        categories = Category.find_all(category_filters)
        category_map = {str(cat._id): cat.name for cat in categories}
        
        pdf_data = None

        # =================================================================
        # ===== LÓGICA DO INTERRUPTOR (LOCAL vs. NUVEM) ===================
        # =================================================================

        if use_hf_worker:
            # --- MODO HÍBRIDO (Termux) ---
            print("🚀 [MODO HÍBRIDO] Delegando geração de PDF para o Worker.")
            
            transactions_data = [t.to_dict() for t in transactions]
            processor = HybridProcessor()
            result = processor.generate_pdf_report(transactions_data, category_map, context)

            if not result or not result.get("success") or not result.get("pdf_base64"):
                error_message = result.get("error", "Falha ao gerar PDF no serviço externo.")
                return jsonify({'error': error_message}), 500

            pdf_data = base64.b64decode(result["pdf_base64"])

        else:
            # --- MODO PRODUÇÃO (Render) ---
            print("🏭 [MODO PRODUÇÃO] Gerando PDF localmente com ReportLab.")
            
            if not REPORTLAB_AVAILABLE:
                return jsonify({'error': 'Biblioteca de relatórios não está disponível no servidor.'}), 500

            # SEU CÓDIGO ORIGINAL COMPLETO PARA GERAR PDF
            buffer = io.BytesIO()
            doc = SimpleDocTemplate(buffer, pagesize=A4)
            elements = []
            
            styles = getSampleStyleSheet()
            title_style = ParagraphStyle(
                'CustomTitle',
                parent=styles['Heading1'],
                fontSize=18,
                spaceAfter=30,
                textColor=colors.HexColor('#1f2937'),
                alignment=1
            )
            
            context_text = 'Empresarial' if context == 'business' else 'Pessoal'
            title = Paragraph(f"Relatório Financeiro - {context_text}", title_style)
            elements.append(title)
            
            date_generated = datetime.now().strftime('%d/%m/%Y às %H:%M')
            date_para = Paragraph(f"Gerado em: {date_generated}", styles['Normal'])
            elements.append(date_para)
            elements.append(Spacer(1, 20))
            
            total_income = sum(t.amount for t in transactions if t.type == 'income')
            total_expenses = sum(t.amount for t in transactions if t.type == 'expense')
            balance = total_income - total_expenses
            
            summary_data = [
                ['RESUMO FINANCEIRO', ''],
                ['Total de Receitas', f"R$ {total_income:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')],
                ['Total de Despesas', f"R$ {total_expenses:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')],
                ['Saldo Líquido', f"R$ {balance:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')],
                ['Total de Transações', str(len(transactions))]
            ]
            
            summary_table = Table(summary_data, colWidths=[3*inch, 2*inch])
            summary_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#3b82f6')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 10),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#f8fafc')),
                ('GRID', (0, 0), (-1, -1), 1, colors.HexColor('#e2e8f0'))
            ]))
            
            elements.append(summary_table)
            elements.append(Spacer(1, 30))
            
            transactions_title = Paragraph("DETALHAMENTO DAS TRANSAÇÕES", styles['Heading2'])
            elements.append(transactions_title)
            elements.append(Spacer(1, 12))
            
            table_data = [['Data', 'Descrição', 'Categoria', 'Tipo', 'Valor']]
            
            sorted_transactions = sorted(transactions, key=lambda x: x.date, reverse=True)
            
            for transaction in sorted_transactions:
                date_str = transaction.date.strftime('%d/%m/%Y') if transaction.date else 'N/A'
                category_name = category_map.get(transaction.category_id, 'Sem categoria')
                type_text = 'Receita' if transaction.type == 'income' else 'Despesa'
                
                amount = transaction.amount
                amount_str = f"+R$ {amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.') if transaction.type == 'income' else f"-R$ {amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
                
                table_data.append([
                    date_str,
                    transaction.description[:40] + ('...' if len(transaction.description) > 40 else ''),
                    category_name[:20] + ('...' if len(category_name) > 20 else ''),
                    type_text,
                    amount_str
                ])
            
            transactions_table = Table(table_data, colWidths=[0.8*inch, 2.5*inch, 1.5*inch, 0.8*inch, 1.2*inch])
            transactions_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#374151')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('ALIGN', (-1, 0), (-1, -1), 'RIGHT'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9fafb')]),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d1d5db')),
                ('TOPPADDING', (0, 1), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 1), (-1, -1), 6),
                ('LEFTPADDING', (0, 0), (-1, -1), 6),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ]))
            
            elements.append(transactions_table)
            doc.build(elements)
            
            buffer.seek(0)
            pdf_data = buffer.getvalue()
            buffer.close()

        # --- SERVIR O ARQUIVO (Comum a ambos os modos) ---
        if pdf_data:
            filename = f"relatorio_{context}_{datetime.now().strftime('%Y%m%d')}.pdf"
            response = make_response(pdf_data)
            response.headers['Content-Type'] = 'application/pdf'
            response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
            return response
        else:
            return jsonify({'error': 'Falha ao gerar os dados do PDF.'}), 500
        
    except Exception as e:
        return jsonify({'error': f'Erro ao gerar PDF: {str(e)}'}), 500

# A rota de CSV segue a mesma estrutura de decisão
@reports_export_bp.route('/api/reports/export-csv', methods=['GET'])
@verify_token
def export_transactions_csv(current_user_uid, current_user_data):
    # ... (código original completo) ...
    try:
        context = request.args.get('context', 'business')
        filters = {'user_id': current_user_uid, 'context': context}
        transactions = Transaction.find_all(filters)
        if not transactions: return jsonify({'error': 'Nenhuma transação encontrada'}), 404
        
        category_filters = {'user_id': current_user_uid, 'context': context}
        categories = Category.find_all(category_filters)
        category_map = {str(cat._id): cat.name for cat in categories}
        
        import csv
        import io
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['Data', 'Descrição', 'Categoria', 'Tipo', 'Valor', 'Status'])
        
        for t in sorted(transactions, key=lambda x: x.date, reverse=True):
            writer.writerow([
                t.date.strftime('%Y-%m-%d') if t.date else 'N/A',
                t.description,
                category_map.get(t.category_id, 'Sem categoria'),
                'Receita' if t.type == 'income' else 'Despesa',
                t.amount,
                t.status or 'pending'
            ])
        
        csv_data = output.getvalue()
        output.close()
        
        filename = f"transacoes_{context}_{datetime.now().strftime('%Y%m%d')}.csv"
        response = make_response(csv_data)
        response.headers['Content-Type'] = 'text/csv; charset=utf-8'
        response.headers['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response
        
    except Exception as e:
        return jsonify({'error': f'Erro ao gerar CSV: {str(e)}'}), 500
