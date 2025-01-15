import os
import shutil
import uuid
import tempfile
from fastapi import APIRouter, File, UploadFile, HTTPException
from typing import Optional
import subprocess

# For synergy retrieval, you might use Chroma or Mongo. We'll example Chroma below.
import chromadb
from chromadb.config import Settings
from langchain.embeddings import OpenAIEmbeddings
# or local embeddings if you prefer
# from langchain.embeddings.huggingface import HuggingFaceEmbeddings

router = APIRouter()

# Initialize Chroma client if you want to store embeddings
# Example:
chroma_client = chromadb.Client(
    Settings(
        chroma_db_impl="duckdb+parquet",
        persist_directory="chroma_data"  # adjust if you have a different path
    )
)

# Create or get a collection for PDF docs
pdf_collection = chroma_client.get_or_create_collection(name="pdf_docs")

@router.post("/upload_pdf")
async def upload_pdf(file: UploadFile = File(...), doc_category: Optional[str] = None):
    """
    Upload a PDF, parse it with MinerU (magic-pdf or similar),
    then store text embeddings in Chroma for future RAG usage.
    doc_category is an optional string to categorize the doc (finance, legal, etc.).
    """
    if file.content_type not in ["application/pdf"]:
        raise HTTPException(status_code=400, detail="Only PDF files supported.")

    # 1) Save the uploaded PDF to a temp file
    temp_dir = tempfile.mkdtemp()
    file_path = os.path.join(temp_dir, file.filename)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # 2) Parse the PDF using MinerU or magic-pdf (example: magic-pdf CLI)
    # Adjust the command if you prefer a Python library call or a different tool.
    # We'll show a CLI approach for demonstration.
    output_md = os.path.join(temp_dir, "parsed_doc.md")

    try:
        # If you have 'magic-pdf' installed, you can do:
        # magic-pdf --input yourfile.pdf --output yourfile.md
        cmd = [
            "magic-pdf",
            "--input", file_path,
            "--output", output_md,
            "--device-mode", "cpu"  # or "cuda", "mps", "npu" if you want acceleration
        ]
        subprocess.run(cmd, check=True)

        # 3) Read the extracted text from output_md
        with open(output_md, "r", encoding="utf-8") as md_file:
            extracted_text = md_file.read()

        # 4) Generate embeddings for the text (splitting into chunks if needed)
        # Simple example: treat the entire doc as one chunk. For more robust RAG,
        # you'd chunk the text by paragraph or ~1000 tokens.
        # If you want to chunk, consider a function that splits text into ~1k token segments.
        chunk_id = str(uuid.uuid4())
        embedding_model = OpenAIEmbeddings()  # or your local embeddings
        # store doc with doc_category if provided
        meta = {"filename": file.filename, "category": doc_category or "general"}
        meta_str = str(meta)

        # Insert into the Chroma collection
        # doc_id can be the chunk_id or something more robust
        docs = [extracted_text]
        doc_ids = [chunk_id]
        metadatas = [meta_str]

        pdf_collection.add(
            documents=docs,
            metadatas=metadatas,
            ids=doc_ids
        )

    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"PDF parsing failed: {str(e)}")
    finally:
        # Clean up the temp dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    return {"status": "success", "message": f"PDF stored. doc_id={chunk_id}", "category": doc_category}
import os
import shutil
import uuid
import tempfile
from fastapi import APIRouter, File, UploadFile, HTTPException
from typing import Optional
import subprocess

# For synergy retrieval, you might use Chroma or Mongo. We'll example Chroma below.
import chromadb
from chromadb.config import Settings
from langchain.embeddings import OpenAIEmbeddings
# or local embeddings if you prefer
# from langchain.embeddings.huggingface import HuggingFaceEmbeddings

router = APIRouter()

# Initialize Chroma client if you want to store embeddings
# Example:
chroma_client = chromadb.Client(
    Settings(
        chroma_db_impl="duckdb+parquet",
        persist_directory="chroma_data"  # adjust if you have a different path
    )
)

# Create or get a collection for PDF docs
pdf_collection = chroma_client.get_or_create_collection(name="pdf_docs")

@router.post("/upload_pdf")
async def upload_pdf(file: UploadFile = File(...), doc_category: Optional[str] = None):
    """
    Upload a PDF, parse it with MinerU (magic-pdf or similar),
    then store text embeddings in Chroma for future RAG usage.
    doc_category is an optional string to categorize the doc (finance, legal, etc.).
    """
    if file.content_type not in ["application/pdf"]:
        raise HTTPException(status_code=400, detail="Only PDF files supported.")

    # 1) Save the uploaded PDF to a temp file
    temp_dir = tempfile.mkdtemp()
    file_path = os.path.join(temp_dir, file.filename)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # 2) Parse the PDF using MinerU or magic-pdf (example: magic-pdf CLI)
    # Adjust the command if you prefer a Python library call or a different tool.
    # We'll show a CLI approach for demonstration.
    output_md = os.path.join(temp_dir, "parsed_doc.md")

    try:
        # If you have 'magic-pdf' installed, you can do:
        # magic-pdf --input yourfile.pdf --output yourfile.md
        cmd = [
            "magic-pdf",
            "--input", file_path,
            "--output", output_md,
            "--device-mode", "cpu"  # or "cuda", "mps", "npu" if you want acceleration
        ]
        subprocess.run(cmd, check=True)

        # 3) Read the extracted text from output_md
        with open(output_md, "r", encoding="utf-8") as md_file:
            extracted_text = md_file.read()

        # 4) Generate embeddings for the text (splitting into chunks if needed)
        # Simple example: treat the entire doc as one chunk. For more robust RAG,
        # you'd chunk the text by paragraph or ~1000 tokens.
        # If you want to chunk, consider a function that splits text into ~1k token segments.
        chunk_id = str(uuid.uuid4())
        embedding_model = OpenAIEmbeddings()  # or your local embeddings
        # store doc with doc_category if provided
        meta = {"filename": file.filename, "category": doc_category or "general"}
        meta_str = str(meta)

        # Insert into the Chroma collection
        # doc_id can be the chunk_id or something more robust
        docs = [extracted_text]
        doc_ids = [chunk_id]
        metadatas = [meta_str]

        pdf_collection.add(
            documents=docs,
            metadatas=metadatas,
            ids=doc_ids
        )

    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"PDF parsing failed: {str(e)}")
    finally:
        # Clean up the temp dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    return {"status": "success", "message": f"PDF stored. doc_id={chunk_id}", "category": doc_category}
