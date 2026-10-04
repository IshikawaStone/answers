import Foundation

public struct SampleData {
    public static func makeSamplePaper() -> ExamPaper {
        var paper = ExamPaper(
            id: "sample_mbbs_medicine_2026",
            title: "MBBS Final Professional - General Medicine",
            date: "2026-09-22",
            totalMarks: 100,
            generationMode: "HONOURS",
            promptSetUsed: "MODULAR_PIPELINE",
            questions: []
        )

        // Q1: Long Question (10 Marks) with Mermaid Flowchart
        var q1 = ExamQuestion(
            id: "q1_dka",
            number: "Q1",
            text: "A 24-year-old known Type 1 Diabetic presents with vomiting, tachypnea, and fruity breath. Outline diagnostic criteria, initial resuscitation protocol, and fluid/insulin management in Diabetic Ketoacidosis (DKA).",
            marks: 10,
            isMcq: false
        )

        q1.honoursAnswer = """
# DIABETIC KETOACIDOSIS (DKA) MANAGEMENT [10 MARKS]

```mermaid
graph TD
  A[Patient with Suspected DKA] --> B{Check Capillary Blood Glucose}
  B -- High > 250 mg/dL --> C[Check Serum Beta-hydroxybutyrate & ABG]
  B -- Normal / Low --> D[Consider Alternative Causes: Sepsis / Euglycemic DKA]
  C -- Anion Gap > 12 & pH < 7.30 --> E[Start 0.9% Normal Saline Resuscitation]
  E --> F{Check Serum Potassium K+}
  F -- K < 3.3 mEq/L --> G[Hold Insulin: Aggressive IV Potassium]
  F -- K >= 3.3 mEq/L --> H[IV Regular Insulin Infusion 0.1 U/kg/hr]
  G --> H
  H --> I[Add 5% Dextrose when BG < 200 mg/dL]
  I --> J[Transition to SC Insulin after Anion Gap Closes]
```

## 1. DIAGNOSTIC CRITERIA (ADA / ISPAD GUIDELINES)
- **Hyperglycemia:** Serum Blood Glucose > **250 mg/dL** (13.9 mmol/L).
- **Acidemia:** Arterial/Venous Blood Gas pH < **7.30** or Serum Bicarbonate (HCO3-) < **18 mEq/L**.
- **Ketonemia / Ketonuria:** Elevated serum beta-hydroxybutyrate > **3.0 mmol/L** or urine acetoacetate > **++**.
- **High Anion Gap Metabolic Acidosis:** Anion Gap = `[Na+] - ([Cl-] + [HCO3-])` > **12 mEq/L**.

## 2. FIRST 24-HOUR RESUSCITATION PROTOCOL
### A. Fluid Resuscitation (Deficit: 5–8 Liters)
- **Hour 1:** 0.9% Normal Saline (NS) at **1000–1500 mL/hr**.
- **Hours 2–4:** 0.9% NS or 0.45% Half-Normal Saline at **250–500 mL/hr**.
- **Euglycemic Switch:** When blood glucose drops to **200–250 mg/dL**, switch fluids to **5% Dextrose in 0.45% Saline** to avoid rapid osmolality drops and cerebral edema.

### B. Intravenous Insulin Strategy
- **Serum Potassium Check First:** If K+ < 3.3 mEq/L, **DO NOT start insulin**. Resuscitate potassium first to prevent fatal arrhythmias.
- **Infusion Rate:** Regular crystalline insulin at **0.1 units/kg/hr IV continuous infusion** (target blood glucose drop 50–75 mg/dL/hr).
- **Resolution Criteria:** Venous pH > 7.30, serum bicarbonate >= 18 mEq/L, and anion gap <= 12 mEq/L.
- **Subcutaneous Transition:** Administer subcutaneous basal insulin (e.g. Glargine) **2 hours prior** to discontinuing IV insulin to avoid rebound ketoacidosis.

## 3. LIFE-THREATENING COMPLICATIONS
1. **Cerebral Edema:** Keep glucose around 200 mg/dL with dextrose once initial levels fall. Treat acutely with IV Mannitol (0.5–1 g/kg).
2. **Severe Hypokalemia:** Strict hourly electrolyte monitoring.
3. **Fluid Overload / ARDS:** Monitor central venous status in renal or cardiac failure patients.
"""
        q1.status = "COMPLETED"
        paper.questions.append(q1)

        // Q2: Short Note (5 Marks)
        var q2 = ExamQuestion(
            id: "q2_nephrotic",
            number: "Q2",
            text: "Write short notes on Nephrotic Syndrome in Adults: Etiology, Hallmark Tetrad, and Diagnostic Renal Biopsy indications.",
            marks: 5,
            isMcq: false
        )

        q2.honoursAnswer = """
# NEPHROTIC SYNDROME IN ADULTS [5 MARKS]

## 1. HALLMARK CLINICAL TETRAD
1. **Heavy Proteinuria:** Urinary protein excretion > **3.5 g / 24 hours** (or urine PCR > 3.5 mg/mg).
2. **Hypoalbuminemia:** Serum albumin < **3.0 g/dL** (due to urinary loss and hepatic synthesis saturation).
3. **Generalized Edema (Anasarca):** Dependent pitting edema, periorbital edema, ascites.
4. **Hyperlipidemia & Lipiduria:** Elevated LDL/cholesterol with fatty casts / 'Maltese cross' oval fat bodies on polarized microscopy.

## 2. ETIOLOGICAL SPECTRUM
- **Primary Glomerular Diseases:**
  - *Membranous Nephropathy (MN):* Leading primary cause in non-diabetic adults (anti-PLA2R antibodies in 70-80%).
  - *Focal Segmental Glomerulosclerosis (FSGS):* Common in young adults.
  - *Minimal Change Disease (MCD):* 10-15% of adult cases.
- **Secondary Causes:**
  - *Diabetic Nephropathy:* Leading secondary cause worldwide.
  - *Lupus Nephritis (Class V):* Young females.
  - *Amyloidosis (AL / AA):* Elderly patients.

## 3. INDICATIONS FOR RENAL BIOPSY
- Mandatory in **all unexplained adult nephrotic syndrome** before initiating immunosuppressive therapy.
- Exceptions where biopsy is deferred:
  - Longstanding Diabetic Retinopathy with typical diabetic nephropathy trajectory.
  - Classic anti-PLA2R positive Membranous Nephropathy with normal renal function.
"""
        q2.status = "COMPLETED"
        paper.questions.append(q2)

        // Q3: MCQ Batch (1 Mark each)
        var mcq1 = ExamQuestion(
            id: "mcq1",
            number: "MCQ 1",
            text: "Which of the following cardiac biomarkers rises first in Acute Myocardial Infarction?",
            marks: 1,
            isMcq: true,
            mcqOptions: ["A. CK-MB", "B. Cardiac Troponin I", "C. Myoglobin", "D. LDH"],
            correctOption: "C. Myoglobin",
            honoursAnswer: """
# MCQ 1: CARDIAC BIOMARKERS IN AMI

- **Correct Answer:** **C. Myoglobin**
- **Explanation:** Myoglobin rises first (1–2 hours after myocardial necrosis), but lacks specificity. Cardiac Troponins (I and T) rise at 3–4 hours, peak at 18–24 hours, and remain elevated for 7–14 days.
""",
            status: "COMPLETED"
        )
        paper.questions.append(mcq1)

        return paper
    }
}
