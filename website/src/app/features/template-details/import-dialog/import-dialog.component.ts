import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';

@Component({
  selector: 'mst-import-dialog',
  imports: [ReactiveFormsModule],
  templateUrl: './import-dialog.component.html',
  styleUrl: './import-dialog.component.scss'
})
export class ImportDialogComponent implements OnInit {

  public form!: FormGroup;

  public get meshStackUrl() {
    return this.form.get('meshStackUrl')?.value;
  }

  constructor(
    public activeModal: NgbActiveModal,
    private fb: FormBuilder
  ) { }

  ngOnInit(): void {
    this.form = this.fb.group({
      meshStackUrl: ['']
    });
  }

  public open() {

  }

}
