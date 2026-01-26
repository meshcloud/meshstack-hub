import { CommonModule, isPlatformBrowser } from '@angular/common';
import { Component, Inject, OnInit, PLATFORM_ID } from '@angular/core';
import { FormBuilder, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { DialogRef, DIALOG_DATA } from '@angular/cdk/dialog';

import { ReferrerService } from 'app/referrer.service';

interface ImportDialogForm {
  meshStackUrl: FormControl<string>;
}

interface ImportDialogData {
  name: string;
  modulePath: string;
}

@Component({
  selector: 'mst-import-dialog',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './import-dialog.component.html',
  styleUrl: './import-dialog.component.scss',
  standalone: true
})
export class ImportDialogComponent implements OnInit {

  public form!: FormGroup<ImportDialogForm>;

  constructor(
    @Inject(PLATFORM_ID) private platformId: object,
    public dialogRef: DialogRef<ImportDialogComponent>,
    @Inject(DIALOG_DATA) public data: ImportDialogData,
    private fb: FormBuilder,
    private referrerService: ReferrerService
  ) { }

  public ngOnInit(): void {
    const originUrl = this.referrerService.getMeshstackUrl();
    this.form = this.fb.group({
      meshStackUrl: this.fb.nonNullable.control(
        originUrl, [Validators.required, Validators.pattern(/^(https?:\/\/).*/)]
      ),
    });
  }

  public openMeshStackUrl() {
    // Only runs in browser, not during SSR
    if (isPlatformBrowser(this.platformId)) {
      const url = this.getSanitizedMeshStackUrl() + '/#/building-block-definition-import?name=' + this.data.name + '&module-path=' + this.data.modulePath;
      window.open(url.toString(), '_blank', 'noopener,noreferrer');
      this.dialogRef.close();
    }
  }

  private getSanitizedMeshStackUrl(): string {
    let meshStackUrl = this.form.controls.meshStackUrl.value;
    const hashIndex = meshStackUrl.indexOf('#');

    if (hashIndex !== -1) {
      meshStackUrl = meshStackUrl.substring(0, hashIndex);
    }

    if (meshStackUrl.endsWith('/')) {
      meshStackUrl = meshStackUrl.slice(0, -1);
    }

    return meshStackUrl;
  }
}
