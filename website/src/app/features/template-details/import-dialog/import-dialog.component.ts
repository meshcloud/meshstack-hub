import { isPlatformBrowser } from '@angular/common';
import { Component, Inject, Input, OnInit, PLATFORM_ID } from '@angular/core';
import { FormBuilder, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';

interface ImportDialogForm {
  meshStackUrl: FormControl<string>;
}

@Component({
  selector: 'mst-import-dialog',
  imports: [ReactiveFormsModule],
  templateUrl: './import-dialog.component.html',
  styleUrl: './import-dialog.component.scss'
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
    private fb: FormBuilder
  ) { }

  public ngOnInit(): void {
    this.form = this.fb.group({
      meshStackUrl: this.fb.nonNullable.control('', [Validators.required, Validators.pattern(/^(https?:\/\/).*/)]),
    });
  }

  public openMeshStackUrl() {
    // Only runs in browser, not during SSR
    if (isPlatformBrowser(this.platformId)) {
      const url = new URL(this.getSanitizedMeshStackUrl());
      url.searchParams.set('module-path', this.modulePath);
      url.searchParams.set('name', this.name);
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
