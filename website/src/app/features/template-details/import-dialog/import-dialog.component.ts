import { CommonModule, isPlatformBrowser } from '@angular/common';
import { Component, Inject, Input, OnInit, PLATFORM_ID } from '@angular/core';
import { FormBuilder, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';

import { ReferrerService } from 'app/referrer.service';

interface ImportDialogForm {
  meshStackUrl: FormControl<string>;
}

@Component({
  selector: 'mst-import-dialog',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './import-dialog.component.html',
  styleUrl: './import-dialog.component.scss',
  standalone: true
})
export class ImportDialogComponent implements OnInit {

  @Input()
  public name!: string;

  @Input()
  public modulePath!: string;

  public form!: FormGroup<ImportDialogForm>;

  constructor(
    @Inject(PLATFORM_ID) private platformId: object,
    public activeModal: NgbActiveModal,
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
      const url = this.getSanitizedMeshStackUrl() + '/#/building-block-definition-import?name=' + this.name + '&module-path=' + this.modulePath;
      window.open(url.toString(), '_blank', 'noopener,noreferrer');
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
